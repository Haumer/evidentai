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
        result = client.generate(
          prompt_snapshot: Ai::Artifacts::ComposeUpdateMessages.messages(
            @user_message,
            current_artifact_text: previous_text
          ),
          model: @context.model
        )

        result.fetch(:text).to_s
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
    end
  end
end
