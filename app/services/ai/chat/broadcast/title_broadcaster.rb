module Ai
  module Chat
    module Broadcast
      class TitleBroadcaster
        TITLE_PARTIAL = "chats/title".freeze
        SIDEBAR_TITLE_PARTIAL = "chats/sidebar_title".freeze

        def initialize(chat:)
          @chat = chat
        end

        def replace(animate: true, include_top: true, include_sidebar: true)
          if include_top
            Turbo::StreamsChannel.broadcast_replace_to(
              @chat,
              target: title_target_id,
              partial: TITLE_PARTIAL,
              locals: { chat: @chat, animate: animate }
            )
          end

          if include_sidebar
            Turbo::StreamsChannel.broadcast_replace_to(
              @chat,
              target: sidebar_title_target_id,
              partial: SIDEBAR_TITLE_PARTIAL,
              locals: { chat: @chat, animate: animate }
            )
          end
        end

        private

        def sidebar_title_target_id
          "chat_#{@chat.id}_sidebar_title"
        end

        def title_target_id
          "chat_#{@chat.id}_title"
        end
      end
    end
  end
end
