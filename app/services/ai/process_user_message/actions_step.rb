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

        broadcaster.replace
      rescue => e
        Rails.logger.warn("[Ai::ProcessUserMessage::ActionsStep] #{e.class}: #{e.message}")
        broadcaster.replace rescue nil
        nil
      end

      private

      def broadcaster
        @broadcaster ||= Ai::Chat::Broadcast::ActionsBroadcaster.new(user_message: @context.user_message)
      end
    end
  end
end
