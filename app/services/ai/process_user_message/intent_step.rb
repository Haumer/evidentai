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
          context: @context.full_chat_history_text,
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
        chat = @context.chat
        applied = false

        chat.with_lock do
          chat.reload
          if chat.can_auto_generate_title?
            title = normalized_title_from_meta
            title = fallback_title_from_first_message if title.blank? && first_user_turn?(chat)

            if title.present?
              chat.update!(title: title, title_generated_at: Time.current)
              applied = true
            end
          end
        end

        return unless applied

        Ai::Chat::Broadcast::TitleBroadcaster.new(chat: chat).replace
      rescue
        nil
      end

      def normalized_title_from_meta
        title = @context.meta.is_a?(Hash) ? @context.meta[:suggested_title].to_s.strip : ""
        return "" if title.blank?
        return "" if ::Chat::UNTITLED_TITLES.include?(title.downcase)

        title
      end

      def fallback_title_from_first_message
        raw = @context.user_message.instruction.to_s.squish
        return "" if raw.blank?

        # Keep the fallback short and readable on both header + sidebar.
        raw.first(72).strip
      end

      def first_user_turn?(chat)
        first_id = chat.user_messages.order(created_at: :asc).limit(1).pluck(:id).first
        first_id.present? && first_id == @context.user_message.id
      end
    end
  end
end
