module Ai
  class ProcessUserMessage
    class Context
      attr_accessor :ai_message, :meta, :artifact_updated
      attr_reader :chat, :model, :provider, :user_message

      def initialize(user_message:, context_text:, model:, provider:)
        @user_message = user_message
        @chat = user_message.chat
        @context_text = context_text.to_s.strip
        @model = model
        @provider = provider
        @artifact_updated = false
      end

      def context_text
        return @context_text if @context_text.present?

        @context_text = Ai::Context::BuildContext.new(
          chat: @chat,
          exclude_user_message_id: @user_message.id
        ).call
      end

      def should_generate_artifact?
        return true if @meta.nil?
        return true if @meta[:should_generate_artifact]

        follow_up_answer_for_artifact_request?
      rescue
        false
      end

      private

      def follow_up_answer_for_artifact_request?
        return false unless chat_supports_history?

        current = @user_message.instruction.to_s.strip
        return false if current.blank?
        return false unless concise_follow_up?(current)

        previous = previous_user_message
        return false unless previous

        previous_user_text = previous.instruction.to_s
        previous_ai_text = previous.ai_message&.text.to_s

        asked_for_more_info = asks_for_more_info?(previous_ai_text)
        return false unless asked_for_more_info

        artifact_related = artifact_request_text?(previous_user_text) || artifact_request_text?(previous_ai_text)
        return false unless artifact_related

        true
      end

      def chat_supports_history?
        @chat.respond_to?(:user_messages) && @chat.user_messages.respond_to?(:where)
      end

      def previous_user_message
        @chat.user_messages
          .where.not(id: @user_message.id)
          .includes(:ai_message)
          .order(created_at: :desc)
          .first
      end

      def concise_follow_up?(text)
        words = text.split(/\s+/)
        words.length <= 8 && text.length <= 80
      end

      def asks_for_more_info?(text)
        s = text.to_s
        return false if s.blank?

        s.include?("?") ||
          s.match?(/\b(where|which|what|when|who|please provide|can you provide|could you share|need)\b/i)
      end

      def artifact_request_text?(text)
        text.to_s.match?(
          /\b(forecast|summary|summari[sz]e|plan|report|analysis|analy[sz]e|checklist|brief|draft|email|itinerary|timeline|proposal|outline|document)\b/i
        )
      end
    end
  end
end
