# app/services/ai/chat/persist_reply.rb
#
# Persistence for assistant chat replies (AiMessage + UserMessage status).
#
# Responsibilities:
# - Ensure an AiMessage exists for the given UserMessage
# - Append streamed deltas into AiMessage.content["text"]
# - Finalize AiMessage and UserMessage statuses on completion
# - Mark failure state on exceptions
#
# This class:
# - Does NOT call the model
# - Does NOT broadcast via Turbo
# - Does NOT know about artifacts

module Ai
  module Chat
    class PersistReply
      def initialize(user_message:)
        @user_message = user_message
      end

      def mark_running!
        @user_message.update!(status: "running", error_message: nil)
      end

      def ensure_ai_message!
        @user_message.ai_message ||
          @user_message.create_ai_message!(content: {}, status: "streaming")
      end

      # Append a delta chunk to AiMessage.content["text"]
      def append_delta!(ai_message:, delta:)
        return if delta.blank?

        content = ai_message.content
        content = {} unless content.is_a?(Hash)

        current_text = content["text"].to_s
        new_text = current_text + delta.to_s

        ai_message.update!(
          content: content.merge("text" => new_text),
          status: "streaming"
        )

        new_text
      end

      # Persist the final assistant text and mark UserMessage done
      def finalize!(ai_message:, text:, model:)
        content = ai_message.content
        content = {} unless content.is_a?(Hash)
        clean_text = Ai::Chat::ConfirmCurrentRequest.call(
          text: text.to_s,
          instruction: @user_message.instruction.to_s
        )

        ai_message.update!(
          content: content.merge("text" => clean_text),
          status: "done"
        )

        @user_message.update!(
          status: "done",
          llm_model: model,
          frozen_at: (@user_message.frozen_at || Time.current)
        )
      end

      def mark_failed!(error)
        @user_message.update!(status: "failed", error_message: error.message)
      end
    end
  end
end
