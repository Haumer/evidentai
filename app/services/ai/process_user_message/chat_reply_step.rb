module Ai
  class ProcessUserMessage
    class ChatReplyStep
      BROADCAST_EVERY_N_CHARS = 10

      def initialize(context:)
        @context = context
        @user_message = context.user_message
      end

      def call
        persist.mark_running!
        ai_message = persist.ensure_ai_message!

        accumulated = +""
        last_broadcast_len = 0

        broadcaster.start(accumulated: accumulated)

        final_text = streamer.call do |delta|
          next if delta.blank?

          accumulated << delta.to_s
          persist.append_delta!(ai_message: ai_message, delta: delta)

          if (accumulated.length - last_broadcast_len) >= BROADCAST_EVERY_N_CHARS
            broadcaster.stream(
              accumulated: Ai::Chat::ConfirmCurrentRequest.call(
                text: accumulated,
                instruction: @user_message.instruction.to_s
              )
            )
            last_broadcast_len = accumulated.length
          end
        end

        persist.finalize!(ai_message: ai_message, text: final_text, model: @context.model)
        broadcaster.final

        @context.ai_message = ai_message
      rescue => e
        persist.mark_failed!(e) rescue nil
        broadcaster.stream(accumulated: "⚠️ #{e.message}") rescue nil
        raise
      end

      private

      def persist
        @persist ||= Ai::Chat::PersistReply.new(user_message: @user_message)
      end

      def broadcaster
        @broadcaster ||= Ai::Chat::Broadcast::ReplyBroadcaster.new(user_message: @user_message)
      end

      def streamer
        @streamer ||= Ai::Chat::StreamReply.new(
          messages: composed_messages,
          model: @context.model
        )
      end

      def composed_messages
        @composed_messages ||= Ai::Chat::ComposeMessages.new(
          user_message: @user_message,
          context: @context.context_text
        ).call
      end
    end
  end
end
