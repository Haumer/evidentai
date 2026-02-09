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

        !!@meta[:should_generate_artifact]
      end
    end
  end
end
