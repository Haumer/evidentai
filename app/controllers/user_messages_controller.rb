# app/controllers/user_messages_controller.rb
class UserMessagesController < ApplicationController
  before_action :ensure_membership!

  # POST /chats/:chat_id/user_messages
  def create
    chat = Chat.where(company: @company).find(params[:chat_id])

    user_message = chat.user_messages.create!(
      company: @company,
      created_by: current_user,
      instruction: params.dig(:user_message, :instruction),
      status: "queued"
    )

    # Kick off AI processing (streaming + actions)
    SubmitUserMessageJob.perform_later(user_message.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          # Append the user message row
          turbo_stream.append(
            "chat_timeline",
            partial: "user_messages/row",
            locals: { user_message: user_message }
          ),

          # Clear composer input
          turbo_stream.update("composer_instruction", ""),

          # Reset composer actions (if any)
          turbo_stream.replace(
            "composer_actions",
            partial: "chats/composer_actions"
          )
        ]
      end

      format.html { redirect_to chat_path(chat) }
    end
  end

  # ---- Legacy / debug endpoint (optional) ----
  # GET /user_messages/:id/status
  #
  # Can be removed once everything is Turbo-streamed.
  def status
    user_message = UserMessage.where(company: @company).find(params[:id])

    ai_message = user_message.ai_message

    render json: {
      id: user_message.id,
      status: user_message.status,
      error_message: user_message.error_message,
      output_text: ai_message&.text
    }
  end

  # PATCH /chats/:chat_id/user_messages/:id/toggle_suggestions
  def toggle_suggestions
    chat = Chat.where(company: @company).find(params[:chat_id])
    user_message = chat.user_messages.find(params[:id])

    dismissed = ActiveModel::Type::Boolean.new.cast(params[:dismissed])
    user_message.update!(settings: user_message.with_suggestions_dismissed(dismissed))

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "assistant_actions_user_message_#{user_message.id}",
          partial: "user_messages/assistant_actions",
          locals: { user_message: user_message, latest: true }
        )
      end

      format.json { render json: { ok: true, dismissed: dismissed } }
      format.html { redirect_to chat_path(chat) }
    end
  end

  private

  def ensure_membership!
    membership = current_user.memberships.first
    redirect_to setup_path and return unless membership
    @company = membership.company
  end
end
