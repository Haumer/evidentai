# app/services/ai/chat/confirm_current_request.rb
#
# Ensures the visible assistant chat text is a single confirmation sentence
# of the current request (no follow-up questions or extra guidance).

module Ai
  module Chat
    class ConfirmCurrentRequest
      MAX_INSTRUCTION_CHARS = 120

      def self.call(text:, instruction:)
        new(text: text, instruction: instruction).call
      end

      def initialize(text:, instruction:)
        @text = text.to_s
        @instruction = instruction.to_s
      end

      def call
        candidate = first_sentence(Ai::Chat::CleanReplyText.call(@text))
        candidate = normalize(candidate)

        return fallback_confirmation if candidate.blank?
        return fallback_confirmation if candidate.include?("?")

        ensure_period(candidate)
      rescue
        fallback_confirmation
      end

      private

      def first_sentence(text)
        str = text.to_s.strip
        return "" if str.empty?

        match = str.match(/\A(.+?[.!?])(?:\s|$)/m)
        (match ? match[1] : str).to_s
      end

      def normalize(text)
        text.to_s.gsub(/\s+/, " ").strip
      end

      def fallback_confirmation
        raw = normalize(@instruction)
        raw = "your request" if raw.empty?

        if raw.length > MAX_INSTRUCTION_CHARS
          raw = raw[0...MAX_INSTRUCTION_CHARS].rstrip
        end

        raw = raw.sub(/[.?!]+\z/, "")
        "Understood, I will work on #{raw}."
      end

      def ensure_period(text)
        text = text.to_s.strip
        text = text.sub(/[?!]+\z/, ".")
        text = "#{text}." unless text.end_with?(".")
        text
      end
    end
  end
end
