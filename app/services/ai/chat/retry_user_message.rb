# app/services/ai/chat/retry_user_message.rb
#
# Requeues an existing user message through the full processing pipeline
# (chat reply + follow-on actions + intent + artifact).

module Ai
  module Chat
    class RetryUserMessage
      def self.call(user_message:)
        new(user_message: user_message).call
      end

      def initialize(user_message:)
        @user_message = user_message
      end

      def call
        raise ArgumentError, "Missing instruction" if @user_message.instruction.to_s.strip.blank?

        @user_message.with_lock do
          @user_message.reload
          raise ArgumentError, "Run already in progress" if @user_message.status.to_s == "running"

          reset_user_message!
          reset_ai_message!
        end

        SubmitUserMessageJob.perform_later(@user_message.id)
        true
      end

      private

      def reset_user_message!
        attrs = { status: "queued", error_message: nil }
        attrs[:artifact_updated_at] = nil if @user_message.respond_to?(:artifact_updated_at)
        @user_message.update!(attrs)
      end

      def reset_ai_message!
        ai_message = @user_message.ai_message
        return unless ai_message

        ai_message.proposed_actions.delete_all if ai_message.respond_to?(:proposed_actions)
        ai_message.ai_message_meta&.destroy!
        ai_message.update!(content: {}, status: "streaming")
      end
    end
  end
end
