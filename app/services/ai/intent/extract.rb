# app/services/ai/intent/extract.rb
#
# Runs the intent extraction call (2nd AI call) and persists to AiMessageMeta.
# Returns a normalized hash suitable for gating later steps.

require "json"

module Ai
  module Intent
    class Extract
      DEFAULT_MODEL = ENV.fetch("OPENAI_MODEL", "gpt-5.2").freeze
      DEFAULT_PROVIDER = ENV.fetch("AI_PROVIDER", "openai").freeze

      def initialize(user_message:, ai_message:, context: nil, model: DEFAULT_MODEL, provider: DEFAULT_PROVIDER)
        @user_message = user_message
        @ai_message = ai_message
        @context = context.to_s.strip
        @model = model
        @client = Ai::Client.new(provider: provider)
      end

      # Returns normalized payload hash:
      # {
      #   should_generate_artifact: true/false,
      #   suggested_title: "..." or nil,
      #   needs_sources: true/false,
      #   suggest_web_search: true/false,
      #   flags: {}
      # }
      def call
        raw_text = run_call
        parsed = parse_json_object(raw_text)
        normalized = normalize(parsed)

        persist!(normalized, raw_payload: parsed)

        normalized
      rescue => e
        fallback = {
          should_generate_artifact: true,  # preserve current behaviour for now
          suggested_title: nil,
          needs_sources: false,
          suggest_web_search: false,
          flags: {}
        }

        persist!(
          fallback,
          raw_payload: {
            "error" => e.message,
            "raw_text" => raw_text.to_s
          }
        ) rescue nil

        fallback
      end

      private

      def run_call
        messages = Ai::Intent::ComposeMessages.new(
          user_message: @user_message,
          context: @context,
          chat_reply_text: @ai_message.text
        ).call

        result = @client.generate(prompt_snapshot: messages, model: @model)
        track_usage!(result)
        result.fetch(:text).to_s
      end

      def track_usage!(result)
        Ai::Usage::TrackRequest.call(
          request_kind: "intent_extract",
          provider: result[:provider].to_s.presence || DEFAULT_PROVIDER,
          model: result[:model].to_s.presence || @model,
          provider_request_id: result[:provider_request_id],
          usage: result[:usage],
          raw: result[:raw],
          user_message: @user_message,
          ai_message: @ai_message,
          chat: @user_message.chat
        )
      rescue
        nil
      end

      def parse_json_object(text)
        str = text.to_s.strip

        return JSON.parse(str) if str.start_with?("{") && str.end_with?("}")

        if (m = str.match(/\{.*\}/m))
          return JSON.parse(m[0])
        end

        raise JSON::ParserError, "No JSON object found"
      end

      def normalize(hash)
        h = hash.is_a?(Hash) ? hash : {}

        should_generate_artifact = !!h["should_generate_artifact"]
        needs_sources = !!h["needs_sources"]
        suggest_web_search = !!h["suggest_web_search"]

        suggested_title = h["suggested_title"].to_s.strip.presence

        flags = h["flags"]
        flags = {} unless flags.is_a?(Hash)

        {
          should_generate_artifact: should_generate_artifact,
          suggested_title: suggested_title,
          needs_sources: needs_sources,
          suggest_web_search: suggest_web_search,
          flags: flags
        }
      end

      def persist!(normalized, raw_payload:)
        meta = @ai_message.ai_message_meta || @ai_message.build_ai_message_meta

        meta.suggested_title = normalized[:suggested_title]
        meta.should_generate_artifact = normalized[:should_generate_artifact]
        meta.needs_sources = normalized[:needs_sources]
        meta.suggest_web_search = normalized[:suggest_web_search]
        meta.flags_json = normalized[:flags] || {}
        meta.payload_json = raw_payload.is_a?(Hash) ? raw_payload : {}

        meta.save!
      end
    end
  end
end
