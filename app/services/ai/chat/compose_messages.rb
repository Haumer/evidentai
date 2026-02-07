# app/services/ai/chat/compose_messages.rb
#
# Builds the message array for the assistant's chat reply (left pane).
# - Owns no prompt text (see Ai::Prompts::ChatSystem)
# - No streaming, persistence, broadcasting, or vendor logic

module Ai
  module Chat
    class ComposeMessages
      def initialize(user_message:, context: nil)
        @user_message = user_message
        @context = context.to_s.strip
      end

      def call
        messages = [{ role: "system", content: Ai::Prompts::ChatSystem::TEXT }]
        messages << { role: "user", content: "Context:\n#{@context}" } if @context.present?
        messages << { role: "user", content: user_text }
        messages
      end

      private

      def user_text
        @user_message.respond_to?(:instruction) ? @user_message.instruction.to_s : @user_message.content.to_s
      end
    end
  end
end
