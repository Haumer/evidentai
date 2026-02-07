# app/services/ai/chat/stream_reply.rb
#
# Streams the assistant chat reply from the model and yields deltas.
#
# Responsibilities:
# - Open a streaming response from the model
# - Parse events and yield delta chunks
# - Return the fully accumulated text
# - Raise on streaming error
#
# This class:
# - Does NOT persist anything
# - Does NOT broadcast anything (Turbo)
# - Does NOT know about artifacts
#
# It is intentionally vendor-shaped for now (OpenAI events) to preserve behavior.
# We'll extract vendor neutrality once streaming is stable.

module Ai
  module Chat
    class StreamReply
      DEFAULT_MODEL = ENV.fetch("OPENAI_MODEL", "gpt-5.2").freeze

      def initialize(messages:, model: DEFAULT_MODEL, openai_client: nil)
        @messages = messages
        @model = model
        @openai_client = openai_client
      end

      # Yields delta strings during streaming.
      # Returns the final accumulated string.
      def call
        accumulated = +""

        stream = client.responses.stream(
          model: @model,
          input: @messages
        )

        stream.each do |event|
          case event_type(event)
          when "response.output_text.delta"
            delta = event_delta(event)
            next if delta.blank?

            accumulated << delta
            yield delta if block_given?

          when "response.completed"
            return accumulated

          when "response.error"
            raise(event_error_message(event) || "OpenAI streaming error")
          end
        end

        accumulated
      end

      private

      def client
        @openai_client ||= OpenAI::Client.new(
          api_key: ENV.fetch("OPENAI_API_KEY")
        )
      end

      def event_type(event)
        event.respond_to?(:type) ? event.type.to_s : event["type"].to_s
      end

      def event_delta(event)
        event.respond_to?(:delta) ? event.delta.to_s : event["delta"].to_s
      end

      def event_error_message(event)
        if event.respond_to?(:error) && event.error.respond_to?(:message)
          event.error.message.to_s
        elsif event.is_a?(Hash) && event["error"].is_a?(Hash)
          event["error"]["message"].to_s
        end
      end
    end
  end
end
