module Ai
  class ProcessUserMessage
    class ActionsStep
      def initialize(context:)
        @context = context
      end

      def call
        Ai::Actions::ExtractProposed
          .new(user_message: @context.user_message, context: @context.context_text)
          .call!
      end
    end
  end
end
