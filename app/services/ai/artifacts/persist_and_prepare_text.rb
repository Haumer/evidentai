# frozen_string_literal: true
#
# app/services/ai/artifacts/persist_and_prepare_text.rb
#
# Persists a NEW artifact version and returns the FINAL html/text that should be displayed.
#
# Rules:
# - Always create a new Artifact row for each generated output version.
# - Inject dataset_json into stored HTML so the iframe reflects the DB dataset.
#
# IMPORTANT:
# - Schema may require artifacts.company_id, artifacts.created_by_id, artifacts.chat_id (NOT NULL).
#   Set *_id fields explicitly to avoid silent failures.

module Ai
  module Artifacts
    class PersistAndPrepareText
      def self.call(chat:, user_message:, generated_text:, dataset_json: nil, sources_json: nil)
        new(
          chat: chat,
          user_message: user_message,
          generated_text: generated_text,
          dataset_json: dataset_json,
          sources_json: sources_json
        ).call
      end

      def initialize(chat:, user_message:, generated_text:, dataset_json:, sources_json:)
        @chat = chat
        @user_message = user_message
        @generated_text = generated_text.to_s
        @dataset_json = dataset_json
        @sources_json = sources_json
      end

      def call
        artifact = Artifact.new(chat_id: @chat.id)

        # Satisfy NOT NULL constraints reliably.
        if Artifact.column_names.include?("company_id")
          artifact.company_id = @user_message.company_id
        end

        if Artifact.column_names.include?("created_by_id")
          artifact.created_by_id = @user_message.created_by_id
        end

        final_text = @generated_text.to_s

        artifact.assign_attributes(artifact_content_attributes(final_text))

        if Artifact.column_names.include?("dataset_json")
          artifact.dataset_json = @dataset_json
        end
        if Artifact.column_names.include?("sources_json")
          artifact.sources_json = @sources_json
        end
        if Artifact.column_names.include?("dataset_locked_by_user")
          artifact.dataset_locked_by_user = false if artifact.dataset_locked_by_user.nil?
        end

        # Ensure displayed/stored HTML reflects whatever dataset_json is currently authoritative.
        if Artifact.column_names.include?("dataset_json") && artifact.dataset_json.present?
          injected = Ai::Artifacts::Dataset::Inject.new(
            html: final_text,
            dataset_json: artifact.dataset_json
          ).call

          final_text = injected.to_s
          artifact.assign_attributes(artifact_content_attributes(final_text))
        end

        artifact.save!

        final_text
      rescue => e
        # Make failures debuggable (validation + NOT NULL issues were being swallowed).
        if defined?(artifact) && artifact.respond_to?(:errors) && artifact.errors.any?
          Rails.logger.warn(
            "[Ai::Artifacts::PersistAndPrepareText] Artifact persist failed: #{e.class}: #{e.message} — #{artifact.errors.full_messages.join(", ")}"
          )
        else
          Rails.logger.warn("[Ai::Artifacts::PersistAndPrepareText] Artifact persist failed: #{e.class}: #{e.message}")
        end

        @generated_text.to_s
      end

      private

      def artifact_content_attributes(text)
        %w[content data body text].each do |col|
          next unless Artifact.column_names.include?(col)

          type = Artifact.columns_hash[col]&.type
          return({ col => { "text" => text.to_s } }) if %i[json jsonb].include?(type)
          return({ col => text.to_s })
        end

        raise "Artifact has no supported content field (expected one of: content/data/body/text)."
      end
    end
  end
end
