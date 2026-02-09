# app/services/ai/chat/broadcast/actions_broadcaster.rb
#
# Turbo broadcaster for assistant follow-on options rendered beneath
# the finalized assistant message.

module Ai
  module Chat
    module Broadcast
      class ActionsBroadcaster
        PARTIAL = "user_messages/assistant_actions".freeze

        def initialize(user_message:)
          @user_message = user_message
          @chat = user_message.chat
        end

        def replace
          Turbo::StreamsChannel.broadcast_replace_to(
            @chat,
            target: actions_target_id,
            partial: PARTIAL,
            locals: { user_message: @user_message, latest: true }
          )
        end

        private

        def actions_target_id
          "assistant_actions_user_message_#{@user_message.id}"
        end
      end
    end
  end
end
