# app/services/ai/submit_user_message.rb
# frozen_string_literal: true

module Ai
  # Legacy-safe wrapper for submitting a UserMessage to the AI pipeline.
  #
  # IMPORTANT:
  # - Your new architecture is job-driven (streaming + turbo broadcasts).
  # - This service should NOT call providers directly or create AiMessages itself.
  # - It should enqueue the job that performs:
  #   Pass 1: conversational output (AiMessage)
  #   Pass 2: proposed actions (ProposedAction rows)
  #
  # Usage:
  #   Ai::SubmitUserMessage.new(user_message: um).call
  #
  class SubmitUserMessage
    def initialize(user_message:, provider: "openai")
      @user_message = user_message
      @provider = provider
    end

    def call
      raise "UserMessage already frozen" if @user_message.frozen_at.present?

      snapshot = build_prompt_snapshot(@user_message)

      @user_message.update!(
        frozen_at: Time.current,
        status: "queued",
        llm_provider: @provider,
        llm_model: (@user_message.llm_model.presence || default_model_for(@provider)),
        prompt_snapshot: snapshot
      )

      SubmitUserMessageJob.perform_later(@user_message.id)

      @user_message.chat.touch
      @user_message
    end

    private

    def build_prompt_snapshot(user_message)
      parts = []
      parts << "INSTRUCTION:\n#{user_message.instruction}".strip

      if user_message.attachments.any?
        parts << "\nATTACHMENTS:"
        user_message.attachments.each_with_index do |a, idx|
          title = a.title.presence || "Untitled"
          body  = a.body.to_s.strip
          parts << "\n[#{idx + 1}] #{a.kind.presence || 'attachment'} — #{title}\n#{body}"
        end
      end

      parts.join("\n")
    end

    def default_model_for(provider)
      case provider
      when "openai" then ENV.fetch("OPENAI_MODEL", "gpt-5.2")
      else ENV.fetch("OPENAI_MODEL", "gpt-5.2")
      end
    end
  end
end
