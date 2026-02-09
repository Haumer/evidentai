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
        {
          content: { text: text },
          raw: chat,
          provider: "openai",
          model: response_model(chat, fallback: model),
          provider_request_id: response_id(chat),
          usage: extract_usage(chat)
        }
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

      def response_model(chat, fallback:)
        if chat.respond_to?(:model)
          chat.model.to_s.presence || fallback.to_s
        elsif chat.is_a?(Hash)
          chat["model"].to_s.presence || fallback.to_s
        else
          fallback.to_s
        end
      end

      def response_id(chat)
        if chat.respond_to?(:id)
          chat.id.to_s.presence
        elsif chat.is_a?(Hash)
          chat["id"].to_s.presence
        end
      end

      def extract_usage(chat)
        usage =
          if chat.respond_to?(:usage)
            chat.usage
          elsif chat.is_a?(Hash)
            chat["usage"]
          end

        {
          input_tokens: usage_value(usage, :prompt_tokens, "prompt_tokens", :input_tokens, "input_tokens"),
          output_tokens: usage_value(usage, :completion_tokens, "completion_tokens", :output_tokens, "output_tokens"),
          total_tokens: usage_value(usage, :total_tokens, "total_tokens")
        }.compact
      end

      def usage_value(usage, *keys)
        return nil if usage.nil?

        keys.each do |key|
          value =
            if usage.respond_to?(key)
              usage.public_send(key)
            elsif usage.is_a?(Hash)
              usage[key] || usage[key.to_s]
            end

          return value.to_i if value.present?
        end

        nil
      end
    end
  end
end
