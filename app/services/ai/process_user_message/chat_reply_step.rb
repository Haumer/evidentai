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
        assumed_defaults = assumed_defaults_for_confirmation

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
                instruction: @user_message.instruction.to_s,
                assumed_defaults: assumed_defaults
              )
            )
            last_broadcast_len = accumulated.length
          end
        end

        persist.finalize!(
          ai_message: ai_message,
          text: final_text,
          model: @context.model,
          assumed_defaults: assumed_defaults
        )
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
          # Keep pass-1 latency low: chat confirmation should not depend on large history.
          context: nil
        ).call
      end

      def assumed_defaults_for_confirmation
        @assumed_defaults_for_confirmation ||= Ai::Chat::AssumedDefaults.call(
          instruction: @user_message.instruction.to_s,
          chat_history_text: @context.full_chat_history_text
        )
      end
    end
  end
end
