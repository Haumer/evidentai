module Ai
  class ProcessUserMessage
    class IntentStep
      def initialize(context:)
        @context = context
      end

      def call
        @context.meta = Ai::Intent::Extract.new(
          user_message: @context.user_message,
          ai_message: @context.ai_message,
          context: @context.context_text,
          model: @context.model,
          provider: @context.provider
        ).call

        apply_title_from_intent!
      rescue
        # Fail-open to preserve existing behavior.
        @context.meta = nil
      end

      private

      def apply_title_from_intent!
        title = @context.meta.is_a?(Hash) ? @context.meta[:suggested_title].to_s.strip : ""
        return if title.blank?

        chat = @context.chat
        applied = false

        chat.with_lock do
          chat.reload
          if chat.can_auto_generate_title?
            chat.update!(title: title)
            applied = true
          end
        end

        return unless applied

        Ai::Chat::Broadcast::TitleBroadcaster.new(chat: chat).replace
      rescue
        nil
      end
    end
  end
end
