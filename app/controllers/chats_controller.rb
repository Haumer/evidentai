# app/controllers/chats_controller.rb
class ChatsController < ApplicationController
  before_action :set_chat, only: %i[show edit update destroy]
  before_action :ensure_membership!

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
  end

  # GET /chats/new
  def new
    @chat = Chat.new
  end

  # GET /chats/1/edit
  def edit
  end

  # POST /chats
  def create
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
    @chat = Chat.find(params[:id])
  end

  def chat_params
    params.require(:chat).permit(:company_id, :created_by_id, :title, :status)
  end

  def ensure_membership!
    membership = current_user.memberships.first
    unless membership
      redirect_to setup_path and return
    end
    @company = membership.company
  end
end
