# app/services/ai/chat/clean_reply_text.rb
#
# Removes internal metadata JSON accidentally appended to assistant-visible text.
# Example tail to strip:
# {"suggested_title":"...","inferred_intent":"..."}

module Ai
  module Chat
    class CleanReplyText
      SIGNAL_KEYS = %w[suggested_title inferred_intent].freeze
      CONTROL_KEYS = %w[should_generate_artifact needs_sources suggest_web_search flags].freeze
      FENCED_JSON_TAIL_REGEX = /```(?:json)?\s*\n(?<json>\{[\s\S]*\})\s*```\s*\z/i.freeze

      def self.call(text)
        new(text).call
      end

      def initialize(text)
        @text = text.to_s
      end

      def call
        stripped = @text.rstrip
        return @text if stripped.empty?

        if (cleaned = strip_trailing_metadata_fence(stripped))
          return cleaned
        end

        if (cleaned = strip_trailing_metadata_object(stripped))
          return cleaned
        end

        @text
      rescue
        @text
      end

      private

      def strip_trailing_metadata_fence(stripped)
        match = stripped.match(FENCED_JSON_TAIL_REGEX)
        return unless match

        parsed = parse_json(match[:json])
        return unless metadata_payload?(parsed) || appended_metadata_payload?(stripped, match[:json])

        stripped[0...match.begin(0)].to_s.rstrip
      end

      def strip_trailing_metadata_object(stripped)
        return unless stripped.end_with?("}")

        json_text, parsed = trailing_json_object(stripped)
        return unless !json_text.to_s.empty?
        return unless metadata_payload?(parsed) || appended_metadata_payload?(stripped, json_text)

        stripped[0, stripped.length - json_text.length].to_s.rstrip
      end

      def trailing_json_object(stripped)
        search_from = stripped.length - 1

        while search_from >= 0
          opening = stripped.rindex("{", search_from)
          break unless opening

          candidate = stripped[opening..]
          parsed = parse_json(candidate)
          return [candidate, parsed] if parsed.is_a?(Hash)

          search_from = opening - 1
        end

        [nil, nil]
      end

      def parse_json(candidate)
        normalized = candidate.to_s
          .gsub(/[“”]/, "\"")
          .gsub(/[‘’]/, "'")

        JSON.parse(normalized)
      rescue
        nil
      end

      def metadata_payload?(hash)
        return false unless hash.is_a?(Hash)

        keys = hash.keys.map(&:to_s)
        return false if keys.empty?

        return true if (keys & SIGNAL_KEYS).any?

        control_triplet = %w[should_generate_artifact needs_sources suggest_web_search]
        return true if control_triplet.all? { |k| keys.include?(k) }

        keys.include?("should_generate_artifact") && keys.include?("flags")
      end

      def appended_metadata_payload?(full_text, json_tail)
        parsed = parse_json(json_tail)
        return false unless parsed.is_a?(Hash)

        prefix = full_text[0, full_text.length - json_tail.length].to_s
        return false if prefix.rstrip.empty?
        return false unless prefix.end_with?("\n")
        return false if json_tail.length > 1500

        true
      rescue
        false
      end
    end
  end
end
