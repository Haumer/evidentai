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
      attr_reader :response_usage, :response_model, :provider_request_id

      def initialize(messages:, model: DEFAULT_MODEL, openai_client: nil)
        @messages = messages
        @model = model
        @openai_client = openai_client
        @response_usage = {}
        @response_model = @model
        @provider_request_id = nil
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
            capture_completion!(event)
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

      def capture_completion!(event)
        response =
          if event.respond_to?(:response)
            event.response
          elsif event.is_a?(Hash)
            event["response"]
          end

        return if response.blank?

        @response_model = extract_value(response, :model, "model").to_s.presence || @model
        @provider_request_id = extract_value(response, :id, "id").to_s.presence

        usage =
          if response.respond_to?(:usage)
            response.usage
          elsif response.is_a?(Hash)
            response["usage"] || response[:usage]
          end

        @response_usage = {
          input_tokens: extract_int(usage, :input_tokens, "input_tokens", :prompt_tokens, "prompt_tokens"),
          output_tokens: extract_int(usage, :output_tokens, "output_tokens", :completion_tokens, "completion_tokens"),
          total_tokens: extract_int(usage, :total_tokens, "total_tokens")
        }.compact
      rescue
        nil
      end

      def extract_value(obj, *keys)
        keys.each do |key|
          value =
            if obj.respond_to?(key)
              obj.public_send(key)
            elsif obj.is_a?(Hash)
              obj[key] || obj[key.to_s]
            end

          return value if value.present?
        end

        nil
      end

      def extract_int(obj, *keys)
        value = extract_value(obj, *keys)
        value.present? ? value.to_i : nil
      end
    end
  end
end
