class ConversationsController < ApplicationController
  before_action :set_conversation, only: %i[ show edit update destroy ]
  before_action :ensure_membership!

  def index
    @conversations = Conversation.where(company: @company).order(updated_at: :desc)

    conversation = @conversations.first || Conversation.create!(
      company: @company,
      created_by: current_user
    )

    redirect_to conversation_path(conversation)
  end

  def show
    @conversations = Conversation.where(company: @company).order(updated_at: :desc)
    @conversation  = @conversations.find(params[:id])

    @prompts = @conversation.prompts.includes(:attachments, :output).order(created_at: :asc)
    @prompt  = Prompt.new
  end

  # GET /conversations/new
  def new
    @conversation = Conversation.new
  end

  # GET /conversations/1/edit
  def edit
  end

  # POST /conversations or /conversations.json
  def create
    # Sidebar “New” button hits this. No form.
    conversation = Conversation.create!(company: @company, created_by: current_user)
    redirect_to conversation_path(conversation)
  end

  # PATCH/PUT /conversations/1 or /conversations/1.json
  def update
    respond_to do |format|
      if @conversation.update(conversation_params)
        format.html { redirect_to @conversation, notice: "Conversation was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @conversation }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @conversation.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /conversations/1 or /conversations/1.json
  def destroy
    @conversation.destroy!

    respond_to do |format|
      format.html { redirect_to conversations_path, notice: "Conversation was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_conversation
      @conversation = Conversation.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def conversation_params
      params.require(:conversation).permit(:company_id, :created_by_id, :title, :status)
    end

    def ensure_membership!
      membership = current_user.memberships.first
      unless membership
        redirect_to setup_path and return
      end
      @company = membership.company
    end
end
