# app/services/ai/context/build_context.rb
#
# Canonical compact context builder for model calls.
#
# Builds a low-token representation of recent conversation turns.
# Designed to be stable so streaming refactors can't accidentally break context.
#
# Output: plain text (Markdown-safe), suitable to embed in a system/user message.
#
# No streaming, no broadcasting, no vendor logic, no artifact awareness.

module Ai
  module Context
    class BuildContext
      DEFAULT_TURNS = 3
      DEFAULT_MAX_CHARS = 3_000
      DEFAULT_USER_CHARS = 220
      DEFAULT_ASSISTANT_CHARS = 280

      def initialize(chat:, exclude_user_message_id: nil, turns: DEFAULT_TURNS, max_chars: DEFAULT_MAX_CHARS)
        @chat = chat
        @exclude_user_message_id = exclude_user_message_id
        @turns = turns.to_i
        @max_chars = max_chars.to_i
      end

      def call
        return "" if @turns <= 0 || @max_chars <= 0

        user_messages = base_scope
          .order(id: :desc)
          .limit(@turns)
          .includes(:ai_message)
          .to_a
          .reverse

        blocks = user_messages.map { |um| block_for(um) }.compact
        blocks = drop_oldest_until_fits(blocks)

        blocks.join("\n\n").strip
      end

      private

      def base_scope
        scope = @chat.user_messages
        return scope unless @exclude_user_message_id.present?

        scope.where.not(id: @exclude_user_message_id)
      end

      def block_for(user_message)
        user_text = compact(extract_user_text(user_message))
        return nil if user_text.empty?

        assistant_text = compact(extract_assistant_text(user_message))

        user_text = truncate(user_text, DEFAULT_USER_CHARS)
        assistant_text = truncate(assistant_text, DEFAULT_ASSISTANT_CHARS)

        assistant_text.empty? ? "U: #{user_text}" : "U: #{user_text}\nA: #{assistant_text}"
      end

      def extract_user_text(user_message)
        if user_message.respond_to?(:instruction) && user_message.instruction.present?
          user_message.instruction.to_s
        else
          user_message.content.to_s
        end
      end

      def extract_assistant_text(user_message)
        ai_message = user_message.ai_message
        return "" unless ai_message

        content = ai_message.content.is_a?(Hash) ? ai_message.content : {}
        Ai::Chat::CleanReplyText.call(content.fetch("text", "").to_s)
      end

      def compact(text)
        text.to_s.gsub(/\s+/, " ").strip
      end

      def truncate(text, max)
        return "" if max.to_i <= 0
        return text if text.length <= max
        text[0, max - 1] + "…"
      end

      def drop_oldest_until_fits(blocks)
        while blocks.length > 1 && blocks.join("\n\n").length > @max_chars
          blocks.shift
        end

        joined = blocks.join("\n\n")
        return blocks if joined.length <= @max_chars

        [joined[-@max_chars, @max_chars]]
      end
    end
  end
end
