# frozen_string_literal: true

module Ai
  class SubmitPrompt
    def initialize(prompt:, provider: "openai")
      @prompt = prompt
      @provider = provider
    end

    def call
      raise "Prompt already frozen" if @prompt.frozen_at.present?

      # 1) Freeze/snapshot
      snapshot = build_prompt_snapshot(@prompt)

      @prompt.update!(
        frozen_at: Time.current,
        status: "frozen",
        llm_provider: @provider,
        llm_model: (@prompt.llm_model.presence || default_model_for(@provider)),
        prompt_snapshot: snapshot
      )

      # 2) Call provider
      client = Ai::Client.new(
        provider: @provider,
      )

      response = client.generate(
        prompt_snapshot: snapshot,
        model: @prompt.llm_model.presence || Ai::Config.default_model_for(@provider),
        settings: @prompt.settings || {}
      )

      # 3) Persist output (MVP: single output)
      @prompt.create_output!(
        kind: "structured",
        status: "ok",
        content: response.fetch(:content)
      )

      @prompt.conversation.touch if @prompt.conversation
      @prompt
    end

    private

    def build_prompt_snapshot(prompt)
      parts = []
      parts << "INSTRUCTION:\n#{prompt.instruction}".strip

      if prompt.attachments.any?
        parts << "\nATTACHMENTS:"
        prompt.attachments.each_with_index do |a, idx|
          title = a.title.presence || "Untitled"
          body  = a.body.to_s.strip
          parts << "\n[#{idx + 1}] #{a.kind.presence || 'attachment'} — #{title}\n#{body}"
        end
      end

      parts.join("\n")
    end

    def default_model_for(provider)
      case provider
      when "openai" then "gpt-4.1"
      else "unknown"
      end
    end

    def env_key_for(provider)
      case provider
      when "openai" then "OPENAI_API_KEY"
      else "AI_API_KEY"
      end
    end
  end
end
