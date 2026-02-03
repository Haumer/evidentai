# app/services/ai/action_catalog.rb
#
# A single source of truth for what the AI is allowed to propose.
# Keep this small + explicit. Add new action types deliberately.
#
# Usage:
#   catalog = Ai::ActionCatalog.catalog
#   Ai::ActionCatalog.allowed_type?("draft_email")
#   Ai::ActionCatalog.validate!("draft_email", payload_hash)
#   Ai::ActionCatalog.as_system_prompt_json
#
# Notes:
# - This is not a full JSON schema validator on purpose (MVP).
# - The server must still treat all actions as "proposals" requiring human approval.

module Ai
  class ActionCatalog
    Action = Struct.new(
      :type,
      :title,
      :description,
      :payload_required_keys,
      :payload_optional_keys,
      :examples,
      keyword_init: true
    )

    # --- Catalog definition ---
    #
    # Keep payload keys stable. If you change them, migrate any stored actions.
    #
    CATALOG = [
      Action.new(
        type: "schedule_prompt",
        title: "Create scheduled prompt",
        description: "Propose a scheduled prompt that runs later on a cadence (cron/RRULE) and posts results into a conversation.",
        payload_required_keys: %w[title schedule timezone sources prompt_template],
        payload_optional_keys: %w[conversation_id enabled],
        examples: [
          {
            title: "Morning news: Kurier, DerStandard, FAZ",
            schedule: "RRULE:FREQ=DAILY;BYHOUR=8;BYMINUTE=0;BYSECOND=0",
            timezone: "Europe/Vienna",
            sources: ["kurier.at", "derstandard.at", "faz.net"],
            prompt_template: "Summarize the top stories from Kurier, Der Standard, and FAZ. Provide bullets with links.",
            enabled: true
          }
        ]
      ),

      Action.new(
        type: "draft_email",
        title: "Draft email",
        description: "Propose an email draft (no sending).",
        payload_required_keys: %w[subject body],
        payload_optional_keys: %w[to cc bcc],
        examples: [
          {
            to: "name@example.com",
            subject: "Follow-up",
            body: "Hi ...\n\nFollowing up on...\n\nBest,\n"
          }
        ]
      ),

      Action.new(
        type: "create_task",
        title: "Create task",
        description: "Propose a task/reminder entry (no automation execution).",
        payload_required_keys: %w[title],
        payload_optional_keys: %w[notes due_at],
        examples: [
          {
            title: "Review supplier contract",
            notes: "Check renewal clause and pricing",
            due_at: "2026-02-10T09:00:00+01:00"
          }
        ]
      ),

      Action.new(
        type: "request_missing_info",
        title: "Request missing info",
        description: "Ask the human for missing fields needed to proceed safely.",
        payload_required_keys: %w[questions],
        payload_optional_keys: %w[],
        examples: [
          { questions: ["Which audience is this for?", "What tone should the email have?"] }
        ]
      )
    ].freeze

    # ---- Public API ----

    def self.catalog
      CATALOG
    end

    def self.types
      CATALOG.map(&:type)
    end

    def self.allowed_type?(type)
      types.include?(type.to_s)
    end

    def self.fetch(type)
      CATALOG.find { |a| a.type == type.to_s }
    end

    # Lightweight validation:
    # - payload must be a Hash
    # - required keys must exist
    # - payload keys must be within required + optional (to keep it tight)
    def self.validate!(type, payload)
      action = fetch(type)
      raise ArgumentError, "Unknown action type: #{type}" unless action

      unless payload.is_a?(Hash)
        raise ArgumentError, "Invalid payload for #{type}: expected Hash"
      end

      required = action.payload_required_keys
      optional = action.payload_optional_keys
      allowed = (required + optional).uniq

      missing = required.reject { |k| payload.key?(k) || payload.key?(k.to_sym) }
      raise ArgumentError, "Invalid payload for #{type}: missing #{missing.join(', ')}" if missing.any?

      # Reject unexpected keys (helps keep outputs stable + safe)
      keys = payload.keys.map(&:to_s)
      unexpected = keys - allowed
      raise ArgumentError, "Invalid payload for #{type}: unexpected #{unexpected.join(', ')}" if unexpected.any?

      true
    end

    # Normalize payload keys to strings and keep only allowed keys.
    def self.normalize_payload(type, payload)
      action = fetch(type)
      return {} unless action
      return {} unless payload.is_a?(Hash)

      allowed = (action.payload_required_keys + action.payload_optional_keys).uniq
      normalized = payload.each_with_object({}) do |(k, v), acc|
        key = k.to_s
        next unless allowed.include?(key)
        acc[key] = v
      end
      normalized
    end

    # This is meant to be embedded in your system prompt.
    # Keep it short and machine-friendly.
    def self.as_system_prompt_json
      {
        allowed_action_types: CATALOG.map do |a|
          {
            type: a.type,
            title: a.title,
            description: a.description,
            payload_required_keys: a.payload_required_keys,
            payload_optional_keys: a.payload_optional_keys,
            examples: a.examples
          }
        end
      }
    end

    # A compact system prompt block you can insert into your OpenAI messages.
    # You can tweak wording later, but this is a strong MVP contract.
    def self.system_prompt_block
      <<~PROMPT
        You are an assistant in a human-in-the-loop system.
        You MUST NOT execute actions. You may only PROPOSE actions from the allowed catalog.
        If you are missing critical information, propose the "request_missing_info" action instead of guessing.

        Output MUST be valid JSON (no markdown fences, no extra text) with this exact shape:
        {
          "content": { "text": "..." },
          "proposed_actions": [
            { "type": "...", "title": "...", "payload": { ... } }
          ]
        }

        Rules:
        - Only propose action types from the catalog below.
        - Payload keys must match the required/optional keys exactly (no extras).
        - proposed_actions may be an empty array.

        Catalog (JSON):
        #{JSON.generate(as_system_prompt_json)}
      PROMPT
    end
  end
end
