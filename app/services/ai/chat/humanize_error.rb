# app/services/ai/chat/humanize_error.rb
#
# Converts provider/raw exceptions into short, user-facing error messages.

module Ai
  module Chat
    class HumanizeError
      DOCS_URL_PATTERN = %r{https?://platform\.openai\.com/docs/\S+}i.freeze

      def self.call(error_or_text)
        new(error_or_text).call
      end

      def initialize(error_or_text)
        @raw = error_or_text.respond_to?(:message) ? error_or_text.message.to_s : error_or_text.to_s
      end

      def call
        text = cleaned_raw

        return quota_message if text.match?(/exceeded your current quota|insufficient_quota/i)
        return auth_message if text.match?(/invalid api key|incorrect api key|unauthorized|401/i)
        return rate_limit_message if text.match?(/rate limit|too many requests|429/i)
        return model_unavailable_message if text.match?(/model.*does not exist|unknown model|not found/i)
        return timeout_message if text.match?(/timeout|timed out|temporar(ily)? unavailable|connection reset|502|503|504/i)

        generic_message(text)
      rescue
        "I couldn't complete that request due to an AI provider error. Please try again."
      end

      private

      def cleaned_raw
        text = @raw.to_s.dup
        text = text.gsub(DOCS_URL_PATTERN, "")
        text = text.gsub(/For more information on this error, read the docs:\s*/i, "")
        text = text.gsub(/\s+/, " ").strip
        text = text.sub(/[.]+\z/, "")
        text
      end

      def quota_message
        "I couldn't complete that request because API quota is exhausted. Please check OpenAI API billing/limits, then retry."
      end

      def auth_message
        "I couldn't authenticate with the AI provider. Please verify the API key and project access, then retry."
      end

      def rate_limit_message
        "I hit a temporary rate limit from the AI provider. Please wait a moment and retry."
      end

      def model_unavailable_message
        "The configured AI model is unavailable for this API key. Please check model access and retry."
      end

      def timeout_message
        "The AI provider timed out while processing your request. Please retry."
      end

      def generic_message(text)
        reason = text.presence || "Unknown provider error"
        "I couldn't complete that request due to an AI provider error: #{reason}."
      end
    end
  end
end
