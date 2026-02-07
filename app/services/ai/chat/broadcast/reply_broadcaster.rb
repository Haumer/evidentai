# app/services/ai/chat/broadcast/reply_broadcaster.rb
#
# Turbo broadcaster for assistant replies in the chat panel.
#
# Responsibilities:
# - Broadcast streaming updates (accumulated text)
# - Broadcast final assistant message
# - Own DOM ids, targets, and partial names
#
# This class:
# - Knows NOTHING about models or streaming internals
# - Knows NOTHING about persistence
# - Knows NOTHING about artifacts
#
# If chat UI changes, only this file (and partials) should need updates.

module Ai
  module Chat
    module Broadcast
      class ReplyBroadcaster
        def initialize(user_message:)
          @user_message = user_message
          @chat = user_message.chat
        end

        # Called before streaming begins (optional but useful for placeholders)
        def start(accumulated: "")
          broadcast_stream(accumulated)
        end

        # Called repeatedly during streaming
        def stream(accumulated:)
          broadcast_stream(accumulated)
        end

        # Called once when streaming is complete
        def final
          Turbo::StreamsChannel.broadcast_replace_to(
            @chat,
            target: assistant_dom_id,
            partial: "user_messages/assistant",
            locals: { user_message: @user_message }
          )
        end

        private

        def broadcast_stream(accumulated)
          Turbo::StreamsChannel.broadcast_replace_to(
            @chat,
            target: assistant_dom_id,
            partial: "user_messages/assistant_stream",
            locals: {
              user_message: @user_message,
              accumulated: accumulated.to_s
            }
          )
        end

        def assistant_dom_id
          "assistant_user_message_#{@user_message.id}"
        end
      end
    end
  end
end
