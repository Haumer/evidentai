# app/services/ai/actions/extract_proposed.rb
#
# Pass 2: Non-streamed strict JSON extraction of proposed actions.
#
# Inputs:
# - user_message.instruction (user request)
# - user_message.ai_message.content["text"] (final chat output from Pass 1)
# - optional context (recent conversation)
#
# Persists:
# - ProposedAction rows for ai_message (idempotent: replaces existing)
# - Stores raw extractor response in ai_message.content["proposed_actions_raw"] (helpful for debugging)
#
# Usage:
#   Ai::Actions::ExtractProposed.new(user_message: user_message, context: "...").call!
#
module Ai
  module Actions
    class ExtractProposed
      DEFAULT_MODEL = ENV.fetch("OPENAI_ACTIONS_MODEL", ENV.fetch("OPENAI_MODEL", "gpt-5.2")).freeze

      def initialize(user_message:, context: nil, include_context_suggestions: true)
        @user_message = user_message
        @context = context.to_s.strip
        @include_context_suggestions = (include_context_suggestions != false)
      end

      def call!
        ai_message = @user_message.ai_message
        raise "UserMessage has no ai_message yet" unless ai_message.present?

        assistant_text = extract_assistant_text(ai_message)
        instruction = @user_message.instruction.to_s

        if acknowledgement_only?(instruction)
          persist_actions!(ai_message: ai_message, extracted_actions: [])
          store_raw!(ai_message: ai_message, raw: "[]", extracted: [])
          return []
        end

        raw = request_actions_json(
          instruction: instruction,
          assistant_text: assistant_text,
          context: @context
        )

        extracted = parse_json_array(raw)

        persist_actions!(ai_message: ai_message, extracted_actions: extracted)
        store_raw!(ai_message: ai_message, raw: raw, extracted: extracted) if persist_raw?

        extracted
      end

      private

      def extract_assistant_text(ai_message)
        content = ai_message.content.is_a?(Hash) ? ai_message.content : {}
        Ai::Chat::CleanReplyText.call(content.fetch("text", "").to_s)
      end

      def request_actions_json(instruction:, assistant_text:, context:)
        allowed_types = allowed_types_for_request

        system =
          if Ai::Actions::Catalog.respond_to?(:extraction_system_prompt)
            Ai::Actions::Catalog.extraction_system_prompt(allowed_types: allowed_types)
          else
            <<~SYSTEM
              You are extracting PROPOSED ACTIONS for a human-in-the-loop system.

              Rules:
              - You MUST output ONLY valid JSON.
              - The JSON MUST be an array of objects.
              - Each object MUST be:
                { "type": String, "payload": Object, "metadata": Object (optional) }
              - "type" MUST be one of the allowed action types from the catalog.
              - If no actions apply, output [].
            SYSTEM
          end

        user = {
          instruction: instruction,
          assistant_text: assistant_text,
          context: (context.presence),
          allowed_action_types: allowed_types
        }.compact

        usage_row = Ai::Usage::TrackRequest.start(
          request_kind: "actions_extract",
          provider: "openai",
          model: DEFAULT_MODEL,
          user_message: @user_message,
          ai_message: @user_message.ai_message,
          chat: @user_message.chat
        )

        resp = openai_client.responses.create(
          model: DEFAULT_MODEL,
          input: [
            { role: "system", content: system },
            { role: "user", content: user.to_json }
          ]
        )
        track_usage!(resp, usage_row: usage_row)

        if resp.respond_to?(:output_text)
          resp.output_text.to_s
        elsif resp.is_a?(Hash)
          (resp["output_text"] || resp.dig("output", 0, "content", 0, "text") || resp["text"]).to_s
        else
          resp.to_s
        end
      rescue => e
        Ai::Usage::TrackRequest.fail!(usage_row: usage_row, error: e.message.to_s) if usage_row.present?
        raise
      end

      def parse_json_array(raw)
        parsed = JSON.parse(raw)
        raise "Extractor returned non-array JSON" unless parsed.is_a?(Array)
        parsed
      rescue JSON::ParserError => e
        raise "Extractor returned invalid JSON: #{e.message}"
      end

      def persist_actions!(ai_message:, extracted_actions:)
        actions = normalize_actions(extracted_actions)

        AiMessage.transaction do
          ai_message.proposed_actions.delete_all

          actions.each do |a|
            type = a.fetch("type")
            next if type == "suggest_additional_context" && !include_context_suggestions?

            payload = a.fetch("payload", {})
            metadata = a.fetch("metadata", {})

            payload = Ai::Actions::Catalog.normalize_payload(type, payload) if Ai::Actions::Catalog.respond_to?(:normalize_payload)
            Ai::Actions::Catalog.validate!(type, payload)

            ai_message.proposed_actions.create!(
              action_type: type,
              payload: payload,
              metadata: metadata
            )
          end
        end
      end

      def normalize_actions(extracted_actions)
        extracted_actions.map do |a|
          raise "Each proposed action must be an object" unless a.is_a?(Hash)

          type = a["type"] || a[:type]
          payload = a["payload"] || a[:payload] || {}
          metadata = a["metadata"] || a[:metadata] || {}

          raise "Proposed action missing type" if type.to_s.strip.empty?
          raise "payload must be a JSON object" unless payload.is_a?(Hash)
          raise "metadata must be a JSON object" unless metadata.is_a?(Hash)

          { "type" => type.to_s, "payload" => payload, "metadata" => metadata }
        end
      end

      def store_raw!(ai_message:, raw:, extracted:)
        content = ai_message.content.is_a?(Hash) ? ai_message.content : {}
        ai_message.update!(
          content: content.merge(
            "proposed_actions_raw" => {
              "raw" => raw.to_s,
              "parsed" => extracted
            }
          )
        )
      end

      def openai_client
        @openai_client ||= OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
      end

      def persist_raw?
        ENV["AI_STORE_ACTIONS_RAW"].to_s == "1"
      end

      def acknowledgement_only?(instruction)
        text = instruction.to_s.strip
        return false if text.blank?

        normalized = text.downcase.gsub(/[^a-z0-9\s]/, " ").squeeze(" ").strip
        return false if normalized.blank?

        normalized.match?(
          /\A(?:thanks|thank you|thx|ok|okay|great|awesome|nice|perfect|cool|sounds good|got it|all good|that works|done)\z/
        )
      end

      def context_suggestions_enabled?
        chat = @user_message.respond_to?(:chat) ? @user_message.chat : nil
        user = @user_message.respond_to?(:created_by) ? @user_message.created_by : nil

        chat_enabled =
          if chat.respond_to?(:context_suggestions_enabled?)
            chat.context_suggestions_enabled?
          elsif chat.respond_to?(:context_suggestions_enabled)
            chat.context_suggestions_enabled != false
          else
            true
          end

        account_enabled =
          if user.respond_to?(:context_suggestions_enabled?)
            user.context_suggestions_enabled?
          elsif user.respond_to?(:context_suggestions_enabled)
            user.context_suggestions_enabled != false
          else
            true
          end

        chat_enabled && account_enabled
      rescue
        true
      end

      def include_context_suggestions?
        @include_context_suggestions && context_suggestions_enabled?
      end

      def allowed_types_for_request
        types =
          if Ai::Actions::Catalog.respond_to?(:allowed_types)
            Ai::Actions::Catalog.allowed_types
          else
            Ai::Actions::Catalog.types
          end

        if include_context_suggestions?
          types
        else
          types.reject { |t| t.to_s == "suggest_additional_context" }
        end
      end

      def track_usage!(response, usage_row:)
        return unless usage_row

        Ai::Usage::TrackRequest.finish!(
          usage_row: usage_row,
          model: DEFAULT_MODEL,
          raw: response,
          metadata: {}
        )
      rescue
        nil
      end
    end
  end
end
