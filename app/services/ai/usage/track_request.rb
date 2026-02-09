module Ai
  module Usage
    class TrackRequest
      class << self
        def call(
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
          row = start(
            request_kind: request_kind,
            provider: provider,
            model: model,
            user_message: user_message,
            ai_message: ai_message,
            chat: chat,
            metadata: metadata,
            requested_at: requested_at
          )
          return nil if row.blank?

          finish!(
            usage_row: row,
            model: model,
            provider_request_id: provider_request_id,
            usage: usage,
            raw: raw,
            metadata: metadata
          )
        rescue => e
          fail!(usage_row: row, error: e.message) if defined?(row) && row.present?
          Rails.logger.info("[Ai::Usage::TrackRequest] failed: #{e.class}: #{e.message}")
          nil
        end

        def start(
          request_kind:,
          provider:,
          model: nil,
          user_message: nil,
          ai_message: nil,
          chat: nil,
          metadata: {},
          requested_at: Time.current
        )
          resolved_chat = resolve_chat(chat: chat, user_message: user_message, ai_message: ai_message)
          return nil if resolved_chat.blank?

          AiRequestUsage.create!(
            company: resolved_chat.company,
            chat: resolved_chat,
            user_message: user_message,
            ai_message: ai_message,
            request_kind: request_kind.to_s,
            provider: provider.to_s,
            model: model.to_s.presence,
            requested_at: requested_at || Time.current,
            status: "running",
            metadata: snapshot_metadata(
              metadata: metadata,
              user_message: user_message,
              chat: resolved_chat
            )
          )
        rescue => e
          Rails.logger.info("[Ai::Usage::TrackRequest] start failed: #{e.class}: #{e.message}")
          nil
        end

        def finish!(
          usage_row:,
          model: nil,
          provider_request_id: nil,
          usage: nil,
          raw: nil,
          metadata: {},
          completed_at: Time.current
        )
          return nil unless usage_row

          final_model =
            model.to_s.presence ||
            usage_row.model.to_s.presence ||
            extract_model(raw)

          usage_hash = normalize_usage(usage || extract_usage(raw))
          input_tokens = usage_hash[:input_tokens]
          output_tokens = usage_hash[:output_tokens]
          total_tokens = usage_hash[:total_tokens]

          pricing = Ai::Usage::Pricing.for_model(final_model)
          input_cost = cost_for(tokens: input_tokens, rate_per_1m: pricing[:input_rate_per_1m_usd])
          output_cost = cost_for(tokens: output_tokens, rate_per_1m: pricing[:output_rate_per_1m_usd])

          usage_row.update!(
            model: final_model,
            provider_request_id: provider_request_id.to_s.presence || extract_request_id(raw) || usage_row.provider_request_id,
            input_tokens: input_tokens,
            output_tokens: output_tokens,
            total_tokens: total_tokens,
            input_rate_per_1m_usd: pricing[:input_rate_per_1m_usd],
            output_rate_per_1m_usd: pricing[:output_rate_per_1m_usd],
            input_cost_usd: input_cost,
            output_cost_usd: output_cost,
            total_cost_usd: input_cost + output_cost,
            status: "completed",
            completed_at: completed_at || Time.current,
            metadata: snapshot_metadata(
              metadata: usage_row.metadata.to_h.merge((metadata.is_a?(Hash) ? metadata : {})),
              user_message: usage_row.user_message,
              chat: usage_row.chat || Chat.find_by(id: usage_row.chat_id)
            )
          )
          usage_row
        rescue => e
          Rails.logger.info("[Ai::Usage::TrackRequest] finish failed: #{e.class}: #{e.message}")
          nil
        end

        def fail!(usage_row:, error:, metadata: {}, completed_at: Time.current)
          return nil unless usage_row

          merged_metadata = usage_row.metadata.to_h.merge((metadata.is_a?(Hash) ? metadata : {}))
          merged_metadata["error"] = error.to_s.presence || "request_failed"

          usage_row.update(
            status: "failed",
            completed_at: completed_at || Time.current,
            metadata: snapshot_metadata(
              metadata: merged_metadata,
              user_message: usage_row.user_message,
              chat: usage_row.chat || Chat.find_by(id: usage_row.chat_id)
            )
          )
          usage_row
        rescue => e
          Rails.logger.info("[Ai::Usage::TrackRequest] fail failed: #{e.class}: #{e.message}")
          nil
        end

        private

        def resolve_chat(chat:, user_message:, ai_message:)
          chat || user_message&.chat || ai_message&.user_message&.chat
        end

        def snapshot_metadata(metadata:, user_message:, chat:)
          merged = metadata.is_a?(Hash) ? metadata.deep_dup.stringify_keys : {}
          merged["actor_user_id"] ||= user_message&.created_by_id || chat&.created_by_id
          merged["chat_id_snapshot"] ||= chat&.id
          merged["chat_title_snapshot"] ||= chat&.title.to_s.presence
          merged["user_message_id_snapshot"] ||= user_message&.id
          merged.compact
        rescue
          metadata.is_a?(Hash) ? metadata : {}
        end

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
        rescue
          {}
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
end
