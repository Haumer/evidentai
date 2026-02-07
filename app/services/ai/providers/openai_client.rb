# frozen_string_literal: true
require "openai"

module Ai
  module Providers
    class OpenaiClient
      DEFAULT_SYSTEM = "You are a careful assistant that produces structured, safe outputs."
      DEFAULT_MODEL = "gpt-5.2"

      def initialize
        @client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
      end

      # prompt_snapshot may be:
      # - String
      # - Array of messages [{role:, content:}, ...]
      #
      # Keep output shape as-is so Ai::Client can normalize consistently.
      def generate(prompt_snapshot:, model:, settings: {})
        messages =
          if prompt_snapshot.is_a?(Array)
            normalize_messages(prompt_snapshot)
          else
            [
              { role: "system", content: DEFAULT_SYSTEM },
              { role: "user", content: prompt_snapshot.to_s }
            ]
          end

        chat = @client.chat.completions.create(
          model: (model || DEFAULT_MODEL),
          messages: messages,
          temperature: settings.fetch("temperature", 0.2)
        )

        text = chat.choices.first.message.content
        { content: { text: text }, raw: chat }
      end

      private

      # Ensure every message is {role: String, content: String}
      # (avoids “content parts” format and the missing type error)
      def normalize_messages(messages)
        messages.map do |m|
          role = (m[:role] || m["role"]).to_s
          content = m[:content] || m["content"]
          { role: role, content: content.to_s }
        end
      end
    end
  end
end
