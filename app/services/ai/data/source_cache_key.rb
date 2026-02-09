require "digest"

module Ai
  module Data
    class SourceCacheKey
      def self.call(query_text)
        new(query_text).call
      end

      def initialize(query_text)
        @query_text = query_text.to_s
      end

      def call
        normalized = normalize(@query_text)
        normalized = "empty-query" if normalized.blank?

        {
          query_text: @query_text.strip,
          normalized_query: normalized,
          query_signature: Digest::SHA256.hexdigest(normalized)
        }
      end

      private

      def normalize(text)
        text.to_s
          .downcase
          .gsub(/[^a-z0-9\s]/, " ")
          .squish
      end
    end
  end
end
