# app/services/ai/chat/broadcast/artifact_broadcaster.rb
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

          # Important:
          # - The Sheets UI (outside the iframe) needs an Artifact record to build edit URLs.
          # - During Turbo updates we are NOT in ChatsController context, so @chat/@artifact
          #   instance vars are not available inside the partial.
          #
          # Therefore we pass `chat:` and `artifact:` explicitly.
          artifact = Artifact.find_by(chat: @chat)

          Turbo::StreamsChannel.broadcast_update_to(
            @chat,
            target: TARGET_ID,
            partial: PARTIAL,
            locals: { text: text, status: status, chat: @chat, artifact: artifact }
          )
        end
      end
    end
  end
end
