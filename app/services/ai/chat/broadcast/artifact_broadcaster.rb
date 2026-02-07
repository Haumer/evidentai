module Ai
  module Chat
    module Broadcast
      class ArtifactBroadcaster
        TARGET_ID = "artifact_content".freeze
        PARTIAL = "chats/artifact_preview".freeze

        def initialize(chat:)
          @chat = chat
        end

        def replace(text:, status: nil)
          text = text.to_s
          status = status.to_s.presence || (text.strip.present? ? "ready" : "waiting")

          Turbo::StreamsChannel.broadcast_update_to(
            @chat,
            target: TARGET_ID,
            partial: PARTIAL,
            locals: { text: text, status: status }
          )
        end
      end
    end
  end
end
