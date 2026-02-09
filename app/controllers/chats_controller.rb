# app/controllers/chats_controller.rb
class ChatsController < ApplicationController
  before_action :ensure_membership!
  before_action :set_chat, only: %i[
    show artifact_preview edit update destroy edit_title update_title sidebar_title toggle_context_suggestions
  ]

  def index
    @chats = Chat.where(company: @company).order(updated_at: :desc)

    chat = @chats.first || Chat.create!(
      company: @company,
      created_by: current_user
    )

    redirect_to chat_path(chat)
  end

  def show
    @chats = Chat.where(company: @company).order(updated_at: :desc)
    @chat  = @chats.find(params[:id])

    @user_messages = @chat.user_messages.includes(:attachments, :ai_message).order(created_at: :asc)
    @user_message  = UserMessage.new

    # Right-side output (latest artifact)
    @artifact = @chat.artifacts.order(created_at: :desc).first
    @artifact_text = @artifact.present? ? artifact_text_for(@artifact) : latest_preview_text
  end

  # Turbo-frame endpoint for artifact version navigation.
  # GET /chats/:id/artifact_preview?artifact_id=123
  def artifact_preview
    artifacts_scope = @chat.artifacts.order(created_at: :desc)
    @artifact =
      if params[:artifact_id].present?
        artifacts_scope.find_by(id: params[:artifact_id]) || artifacts_scope.first
      else
        artifacts_scope.first
      end

    if @artifact.present?
      requested_text = artifact_text_for(@artifact)
      if requested_text.blank?
        fallback_artifact = artifacts_scope.detect { |candidate| artifact_text_for(candidate).present? }
        @artifact = fallback_artifact if fallback_artifact.present?
      end
    end

    artifact_text = @artifact.present? ? artifact_text_for(@artifact) : latest_preview_text
    status = artifact_text.present? ? "ready" : "waiting"

    locals = {
      text: artifact_text,
      status: status,
      chat: @chat,
      artifact: @artifact
    }

    if turbo_frame_request?
      render partial: "chats/artifact_preview_frame", locals: locals
    else
      render partial: "chats/artifact_preview", locals: locals
    end
  end

  # GET /chats/new
  def new
    @chat = Chat.new
  end

  # GET /chats/1/edit
  def edit
  end

  # Sidebar inline title edit (Turbo Frame)
  # GET /chats/:id/edit_title
  def edit_title
    render partial: "chats/sidebar_title_form", locals: { chat: @chat }
  end

  # Sidebar inline title display (Turbo Frame)
  # GET /chats/:id/sidebar_title
  def sidebar_title
    render partial: "chats/sidebar_title", locals: { chat: @chat }
  end

  # Sidebar inline title update (Turbo Frame)
  # PATCH /chats/:id/update_title
  def update_title
    title = params.require(:chat).fetch(:title).to_s.strip
    title = title.presence

    @chat.update!(
      title: title,
      title_set_by_user: true
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "chat_#{@chat.id}_title",
            partial: "chats/title",
            locals: { chat: @chat, animate: true }
          ),
          turbo_stream.replace(
            "chat_#{@chat.id}_sidebar_title",
            partial: "chats/sidebar_title",
            locals: { chat: @chat, animate: true }
          )
        ]
      end

      format.html { redirect_to chat_path(@chat) }
    end
  end

  # PATCH /chats/:id/toggle_context_suggestions
  def toggle_context_suggestions
    scope = params[:scope].to_s
    scope = "chat" unless %w[chat account].include?(scope)

    enabled = resolve_suggestions_enabled(scope: scope)

    if scope == "account"
      current_user.update!(context_suggestions_enabled: enabled)
      dismiss_pending_context_suggestions!(all_chat_ids: company_chat_ids) unless enabled
    else
      @chat.update!(context_suggestions_enabled: enabled)
      dismiss_pending_context_suggestions!(all_chat_ids: [@chat.id]) unless enabled
    end

    user_message = @chat.user_messages.find_by(id: params[:user_message_id])

    respond_to do |format|
      format.turbo_stream do
        if user_message
          render turbo_stream: turbo_stream.replace(
            "assistant_actions_user_message_#{user_message.id}",
            partial: "user_messages/assistant_actions",
            locals: { user_message: user_message, latest: true }
          )
        else
          head :ok
        end
      end

      format.html { redirect_to chat_path(@chat) }
    end
  end

  # POST /chats
  def create
    blocking_chat = blocking_untouched_chat
    if blocking_chat.present?
      redirect_to chat_path(blocking_chat), alert: "Finish or rename your current empty chat before creating a new one."
      return
    end

    # Sidebar “New” button hits this. No form.
    chat = Chat.create!(company: @company, created_by: current_user)
    redirect_to chat_path(chat)
  end

  # PATCH/PUT /chats/1
  def update
    respond_to do |format|
      if @chat.update(chat_params)
        format.html { redirect_to @chat, notice: "Chat was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @chat }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @chat.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /chats/1
  def destroy
    @chat.destroy!

    respond_to do |format|
      format.html { redirect_to chats_path, notice: "Chat was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def set_chat
    @chat = Chat.where(company: @company).find(params[:id])
  end

  def chat_params
    params.require(:chat).permit(:title, :status)
  end

  def ensure_membership!
    membership = current_user.memberships.first
    unless membership
      redirect_to setup_path and return
    end
    @company = membership.company
  end

  def latest_preview_text
    @chat.user_messages.reverse_each.lazy
      .map { |um| um.ai_message&.content&.dig("preview").to_s }
      .find { |t| t.present? }.to_s
  end

  def artifact_text_for(artifact)
    return "" unless artifact

    if artifact.respond_to?(:content) && artifact.content.present?
      artifact.content.is_a?(Hash) ? artifact.content["text"].to_s : artifact.content.to_s
    elsif artifact.respond_to?(:data) && artifact.data.present?
      artifact.data.is_a?(Hash) ? artifact.data["text"].to_s : artifact.data.to_s
    elsif artifact.respond_to?(:body) && artifact.body.present?
      artifact.body.to_s
    elsif artifact.respond_to?(:text) && artifact.text.present?
      artifact.text.to_s
    else
      ""
    end
  end

  def resolve_suggestions_enabled(scope:)
    current_enabled =
      if scope == "account"
        current_user.respond_to?(:context_suggestions_enabled?) ? current_user.context_suggestions_enabled? : true
      else
        @chat.context_suggestions_enabled?
      end

    if params[:enabled].nil?
      !current_enabled
    else
      ActiveModel::Type::Boolean.new.cast(params[:enabled])
    end
  end

  def dismiss_pending_context_suggestions!(all_chat_ids:)
    ProposedAction.joins(ai_message: :user_message)
      .where(user_messages: { chat_id: all_chat_ids })
      .where(action_type: "suggest_additional_context", status: "proposed")
      .update_all(
        status: "dismissed",
        dismissed_at: Time.current,
        dismissed_by_id: current_user.id,
        updated_at: Time.current
      )
  end

  def company_chat_ids
    Chat.where(company: @company).pluck(:id)
  end

  def blocking_untouched_chat
    if params[:current_chat_id].present?
      current_chat = Chat.where(company: @company).find_by(id: params[:current_chat_id])
      return current_chat if current_chat&.untouched_for_new_chat?
    end

    latest_chat = Chat.where(company: @company).order(updated_at: :desc).first
    return nil unless latest_chat&.untouched_for_new_chat?

    latest_chat
  end
end
