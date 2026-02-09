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
      rescue
        # Fail-open to preserve existing behavior.
        @context.meta = nil
      end
    end
  end
end
