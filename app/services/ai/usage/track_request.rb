module Ai
  module Usage
    class TrackRequest
      def self.call(
        request_kind:,
        provider:,
        model: nil,
        user_message: nil,
        ai_message: nil,
        chat: nil,
        usage: nil,
        raw: nil,
        provider_request_id: nil,
        metadata: {},
        requested_at: Time.current
      )
        new(
          request_kind: request_kind,
          provider: provider,
          model: model,
          user_message: user_message,
          ai_message: ai_message,
          chat: chat,
          usage: usage,
          raw: raw,
          provider_request_id: provider_request_id,
          metadata: metadata,
          requested_at: requested_at
        ).call
      end

      def initialize(
        request_kind:,
        provider:,
        model:,
        user_message:,
        ai_message:,
        chat:,
        usage:,
        raw:,
        provider_request_id:,
        metadata:,
        requested_at:
      )
        @request_kind = request_kind.to_s
        @provider = provider.to_s
        @user_message = user_message
        @ai_message = ai_message
        @chat = chat || user_message&.chat || ai_message&.user_message&.chat
        @model = model.to_s.presence || extract_model(raw)
        @provider_request_id = provider_request_id.to_s.presence || extract_request_id(raw)
        @usage = normalize_usage(usage || extract_usage(raw))
        @metadata = metadata.is_a?(Hash) ? metadata : {}
        @requested_at = requested_at || Time.current
      end

      def call
        return if @chat.blank?

        pricing = Ai::Usage::Pricing.for_model(@model)
        input_tokens = @usage[:input_tokens]
        output_tokens = @usage[:output_tokens]
        total_tokens = @usage[:total_tokens]

        input_cost = cost_for(tokens: input_tokens, rate_per_1m: pricing[:input_rate_per_1m_usd])
        output_cost = cost_for(tokens: output_tokens, rate_per_1m: pricing[:output_rate_per_1m_usd])

        AiRequestUsage.create!(
          company: @chat.company,
          chat: @chat,
          user_message: @user_message,
          ai_message: @ai_message,
          request_kind: @request_kind,
          provider: @provider,
          model: @model,
          provider_request_id: @provider_request_id,
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          total_tokens: total_tokens,
          input_rate_per_1m_usd: pricing[:input_rate_per_1m_usd],
          output_rate_per_1m_usd: pricing[:output_rate_per_1m_usd],
          input_cost_usd: input_cost,
          output_cost_usd: output_cost,
          total_cost_usd: input_cost + output_cost,
          requested_at: @requested_at,
          metadata: @metadata
        )
      rescue => e
        Rails.logger.info("[Ai::Usage::TrackRequest] failed: #{e.class}: #{e.message}")
        nil
      end

      private

      def normalize_usage(usage)
        input = token_value(usage, :input_tokens, :prompt_tokens)
        output = token_value(usage, :output_tokens, :completion_tokens)
        total = token_value(usage, :total_tokens)
        total = input + output if total.zero? && (input.positive? || output.positive?)

        { input_tokens: input, output_tokens: output, total_tokens: total }
      end

      def extract_usage(raw)
        return {} if raw.nil?

        usage =
          if raw.respond_to?(:usage)
            raw.usage
          elsif raw.is_a?(Hash)
            raw[:usage] || raw["usage"]
          end

        return {} if usage.blank?

        {
          input_tokens: token_value(usage, :input_tokens, :prompt_tokens),
          output_tokens: token_value(usage, :output_tokens, :completion_tokens),
          total_tokens: token_value(usage, :total_tokens)
        }
      end

      def token_value(obj, *keys)
        keys.each do |key|
          value =
            if obj.respond_to?(key)
              obj.public_send(key)
            elsif obj.is_a?(Hash)
              obj[key] || obj[key.to_s]
            end

          return value.to_i if value.present?
        end

        0
      end

      def extract_model(raw)
        return nil if raw.nil?

        if raw.respond_to?(:model)
          raw.model.to_s.presence
        elsif raw.is_a?(Hash)
          (raw[:model] || raw["model"]).to_s.presence
        end
      rescue
        nil
      end

      def extract_request_id(raw)
        return nil if raw.nil?

        if raw.respond_to?(:id)
          raw.id.to_s.presence
        elsif raw.is_a?(Hash)
          (raw[:id] || raw["id"]).to_s.presence
        end
      rescue
        nil
      end

      def cost_for(tokens:, rate_per_1m:)
        return 0.to_d if tokens.to_i <= 0
        return 0.to_d if rate_per_1m.to_d <= 0

        (tokens.to_d / 1_000_000.to_d) * rate_per_1m.to_d
      end
    end
  end
end
