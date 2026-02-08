# app/services/ai/intent/compose_messages.rb
#
# Builds the message array for intent extraction (control plane).
# JSON-only output. Non-streamed.

module Ai
  module Intent
    class ComposeMessages
      def initialize(user_message:, context: nil, chat_reply_text: nil)
        @user_message = user_message
        @context = context.to_s.strip
        @chat_reply_text = chat_reply_text.to_s.strip
      end

      def call
        messages = [{ role: "system", content: Ai::Prompts::IntentSystem::TEXT }]

        messages << { role: "user", content: "Context:\n#{@context}" } if @context.present?
        messages << { role: "user", content: "User message:\n#{user_text}" }
        messages << { role: "user", content: "Assistant chat reply (non-authoritative):\n#{@chat_reply_text}" } if @chat_reply_text.present?

        messages
      end

      private

      def user_text
        @user_message.respond_to?(:instruction) ? @user_message.instruction.to_s : @user_message.content.to_s
      end
    end
  end
end
