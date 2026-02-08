# frozen_string_literal: true
#
# app/services/ai/artifacts/current_text.rb
#
# Returns the most recent artifact HTML/text for a chat (as a plain String).
#
# Notes:
# - Artifacts have used different storage columns over time (content/data/body/text).
# - Some columns may be json/jsonb with shape { "text": "..." }.
# - This service is intentionally defensive to preserve current behavior.

module Ai
  module Artifacts
    class CurrentText
      def self.call(chat:)
        new(chat: chat).call
      end

      def initialize(chat:)
        @chat = chat
      end

      def call
        artifact = Artifact.where(chat_id: @chat.id).order(created_at: :desc).first
        return "" unless artifact

        read_textish_column(artifact)
      end

      private

      def read_textish_column(artifact)
        if artifact.respond_to?(:content) && artifact.content.present?
          return artifact.content.is_a?(Hash) ? artifact.content["text"].to_s : artifact.content.to_s
        end

        if artifact.respond_to?(:data) && artifact.data.present?
          return artifact.data.is_a?(Hash) ? artifact.data["text"].to_s : artifact.data.to_s
        end

        if artifact.respond_to?(:body) && artifact.body.present?
          return artifact.body.to_s
        end

        if artifact.respond_to?(:text) && artifact.text.present?
          return artifact.text.to_s
        end

        ""
      end
    end
  end
end
