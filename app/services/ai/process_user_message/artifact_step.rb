module Ai
  class ProcessUserMessage
    class ArtifactStep
      MIN_OUTPUT_WORKING_MS = 350

      def initialize(context:)
        @context = context
        @chat = context.chat
        @user_message = context.user_message
      end

      def call
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        previous_text = Ai::Artifacts::CurrentText.call(chat: @chat)

        run_status_broadcaster.working
        artifact_broadcaster.replace(text: previous_text, status: "working")

        generated_text = generate_artifact_text(previous_text)
        extracted = Ai::Artifacts::Dataset::Extract.call(generated_text)
        update_preview!(generated_text)

        final_text = Ai::Artifacts::PersistAndPrepareText.call(
          chat: @chat,
          user_message: @user_message,
          generated_text: generated_text,
          dataset_json: extracted[:dataset_json],
          sources_json: extracted[:sources_json]
        )

        persist_artifact_updated_status!
        artifact_broadcaster.replace(text: final_text.to_s, status: "ready")

        wait_for_minimum_working_duration(started_at)
        run_status_broadcaster.ready
        @context.artifact_updated = true
      rescue => e
        artifact_broadcaster.replace(
          text: "⚠️ Failed to generate output: #{e.message}",
          status: "ready"
        )
        run_status_broadcaster.clear rescue nil
        @context.artifact_updated = false
      end

      private

      def generate_artifact_text(previous_text)
        data_resolution = resolve_available_data
        persist_data_resolution_flags!(data_resolution)

        result = client.generate(
          prompt_snapshot: Ai::Artifacts::ComposeUpdateMessages.messages(
            @user_message,
            current_artifact_text: previous_text,
            available_data: data_resolution[:available_data],
            chat_history: @context.full_chat_history_text
          ),
          model: @context.model
        )

        track_usage!(result)
        result.fetch(:text).to_s
      end

      def resolve_available_data
        @resolve_available_data ||= Ai::Data::ResolveAvailableData.new(context: @context).call
      end

      def persist_data_resolution_flags!(resolution)
        ai_message = @context.ai_message
        return unless ai_message

        meta = ai_message.ai_message_meta || ai_message.build_ai_message_meta
        flags = meta.flags_json.is_a?(Hash) ? meta.flags_json.deep_dup : {}
        flags["data_resolution"] = {
          "needed" => resolution[:needed] == true,
          "decision" => resolution[:decision].to_s,
          "forced_refresh" => resolution[:forced_refresh] == true,
          "query_signature" => resolution[:query_signature].to_s,
          "error" => resolution[:error].to_s.presence
        }.compact

        meta.flags_json = flags
        meta.save!
      rescue => e
        Rails.logger.info("[ArtifactStep] failed to persist data resolution flags: #{e.class}: #{e.message}")
        nil
      end

      def update_preview!(generated_text)
        ai_message = @context.ai_message
        return unless ai_message

        content = ai_message.content
        content = {} unless content.is_a?(Hash)
        ai_message.update!(content: content.merge("preview" => generated_text))
      rescue
        nil
      end

      def wait_for_minimum_working_duration(started_at)
        elapsed_ms =
          ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000.0).round
        remaining_ms = MIN_OUTPUT_WORKING_MS - elapsed_ms
        sleep(remaining_ms / 1000.0) if remaining_ms.positive?
      end

      def persist_artifact_updated_status!
        return unless @user_message.respond_to?(:artifact_updated_at)

        @user_message.update!(artifact_updated_at: Time.current)
      rescue
        nil
      end

      def client
        @client ||= Ai::Client.new(provider: @context.provider)
      end

      def artifact_broadcaster
        @artifact_broadcaster ||= Ai::Chat::Broadcast::ArtifactBroadcaster.new(chat: @chat)
      end

      def run_status_broadcaster
        @run_status_broadcaster ||= Ai::Chat::Broadcast::RunStatusBroadcaster.new(
          chat: @chat,
          user_message: @user_message
        )
      end

      def track_usage!(result)
        Ai::Usage::TrackRequest.call(
          request_kind: "artifact_generate",
          provider: result[:provider].to_s.presence || @context.provider,
          model: result[:model].to_s.presence || @context.model,
          provider_request_id: result[:provider_request_id],
          usage: result[:usage],
          raw: result[:raw],
          user_message: @user_message,
          ai_message: @context.ai_message,
          chat: @chat
        )
      rescue
        nil
      end
    end
  end
end
