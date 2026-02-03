class PromptsController < ApplicationController
  before_action :set_prompt, only: %i[ show edit update destroy ]
  before_action :ensure_membership!

  # GET /prompts or /prompts.json
  def index
    @prompts = Prompt.all
  end

  # GET /prompts/1 or /prompts/1.json
  def show
  end

  # GET /prompts/new
  def new
    @prompt = Prompt.new
  end

  # GET /prompts/1/edit
  def edit
  end

  def create
    conversation = Conversation.where(company: @company).find(params[:conversation_id])

    prompt = conversation.prompts.create!(
      company: @company,
      created_by: current_user,
      instruction: params.dig(:prompt, :instruction),
      status: "queued"
    )

    SubmitPromptJob.perform_later(prompt.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append(
            "chat_timeline",
            partial: "prompts/row",
            locals: { prompt: prompt }
          ),
          turbo_stream.update("composer_instruction", ""),
          turbo_stream.replace("composer_actions", partial: "conversations/composer_actions")
        ]
      end

      format.html { redirect_to conversation_path(conversation) }
    end
  end

  # Poll endpoint: returns output (or status) for one prompt
  def status
    prompt = Prompt.where(company: @company).find(params[:id])

    text = nil
    if prompt.output&.content.is_a?(Hash)
      text = prompt.output.content["text"]
    end

    render json: {
      id: prompt.id,
      status: prompt.status,
      error_message: prompt.error_message,
      output_text: text
    }
  end

  def submit
    prompt = Prompt.find(params[:id])

    Ai::SubmitPrompt.new(prompt: prompt, provider: "openai").call

    redirect_to conversation_path(prompt.conversation)
  end

  # PATCH/PUT /prompts/1 or /prompts/1.json
  def update
    respond_to do |format|
      if @prompt.update(prompt_params)
        format.html { redirect_to @prompt, notice: "Prompt was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @prompt }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @prompt.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /prompts/1 or /prompts/1.json
  def destroy
    @prompt.destroy!

    respond_to do |format|
      format.html { redirect_to prompts_path, notice: "Prompt was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

    def kick_off_ai_generation(prompt_id)
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          prompt = Prompt.find(prompt_id)
          prompt.update!(status: "running", error_message: nil)

          Ai::SubmitPrompt.new(prompt: prompt, provider: "openai").call

          # Ai::SubmitPrompt should create output; we mark done here
          prompt.update!(status: "done")
        rescue => e
          # Avoid raising in thread; persist failure state
          begin
            prompt&.update!(status: "failed", error_message: e.message)
          rescue
            # swallow: thread must not crash the process
          end
        end
      end
    end

    def ensure_membership!
      membership = current_user.memberships.first
      redirect_to setup_path and return unless membership
      @company = membership.company
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_prompt
      @prompt = Prompt.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def prompt_params
      params.require(:prompt).permit(:company_id, :created_by_id, :instruction, :status, :frozen_at, :llm_provider, :llm_model, :prompt_snapshot, :settings)
    end
end
