# app/services/ai/artifacts/compose_update_messages.rb
#
# Builds the model input for updating the OUTPUT artifact (right pane).
#
# Responsibility:
# - Given the current artifact + the user's latest request,
#   return ONLY the updated artifact content (markdown).
#
# This is NOT a "prompt" in the application sense.
# It is a deterministic artifact update instruction set.
#
# No streaming, no persistence, no broadcasting.

module Ai
  module Artifacts
    class ComposeUpdateMessages
      def self.messages(user_message, current_artifact_text:)
        current = current_artifact_text.to_s
        request = user_message.instruction.to_s

        [
          { role: "system", content: Ai::Prompts::OutputEditorSystem::TEXT },
          {
            role: "user",
            content: <<~TEXT
              CURRENT_ARTIFACT:
              #{current.present? ? current : "(empty)"}

              CHANGE_REQUEST:
              #{request}

              Return UPDATED_ARTIFACT only.
            TEXT
          }
        ]
      end
    end
  end
end
