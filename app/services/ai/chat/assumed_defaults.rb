module Ai
  module Chat
    class AssumedDefaults
      TRAVEL_SCOPE_PATTERN = /\b(around|near|nearby|within)\b/i
      EXPLICIT_RADIUS_PATTERN = /\b\d+\s*(?:min|mins|minute|minutes|hour|hours|hr|hrs|km|kilometers?|kilometres?|mi|mile|miles)\b/i

      def self.call(instruction:, chat_history_text: nil)
        new(instruction: instruction, chat_history_text: chat_history_text).call
      end

      def initialize(instruction:, chat_history_text:)
        @instruction = instruction.to_s
        @chat_history_text = chat_history_text.to_s
      end

      def call
        defaults = []
        defaults << "a 60-minute travel radius" if travel_scope_without_radius?
        defaults
      rescue
        []
      end

      private

      def corpus
        @corpus ||= [@chat_history_text, @instruction].reject(&:blank?).join("\n")
      end

      def travel_scope_without_radius?
        corpus.match?(TRAVEL_SCOPE_PATTERN) && !corpus.match?(EXPLICIT_RADIUS_PATTERN)
      end
    end
  end
end
