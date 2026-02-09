# app/services/ai/chat/broadcast/run_status_broadcaster.rb
#
# Turbo broadcaster for the "Updating output…" status shown directly beneath
# the assistant message for the current user_message.
# Also controls composer enabled/disabled state during artifact regeneration.

module Ai
  module Chat
    module Broadcast
      class RunStatusBroadcaster
        RUN_STATUS_PARTIAL = "chats/run_status".freeze

        COMPOSER_TARGET_ID = "composer_actions".freeze
        COMPOSER_PARTIAL = "chats/composer_actions".freeze

        def initialize(chat:, user_message:)
          @chat = chat
          @user_message = user_message
        end

        def working(started_at: Time.current)
          replace_run_status(state: "working", started_at: started_at)
          update_composer(disabled: true)
        end

        def ready
          replace_run_status(state: "ready", started_at: nil)
          update_composer(disabled: false)
        end

        def clear
          # Keep the stable target in the DOM; just render "idle" (empty UI).
          replace_run_status(state: "idle", started_at: nil)
        end

        private

        def replace_run_status(state:, started_at:)
          Turbo::StreamsChannel.broadcast_replace_to(
            @chat,
            target: run_status_target_id,
            partial: RUN_STATUS_PARTIAL,
            locals: {
              user_message_id: @user_message.id,
              state: state,
              started_at: started_at
            }
          )
        end

        def update_composer(disabled:)
          Turbo::StreamsChannel.broadcast_replace_to(
            @chat,
            target: COMPOSER_TARGET_ID,
            partial: COMPOSER_PARTIAL,
            locals: { disabled: disabled }
          )
        end

        def run_status_target_id
          "assistant_run_status_user_message_#{@user_message.id}"
        end
      end
    end
  end
end
