# app/services/ai/actions/catalog.rb
#
# A single source of truth for what the AI is allowed to propose.
# Keep this small + explicit. Add new action types deliberately.
#
# Usage:
#   catalog = Ai::Actions::Catalog.catalog
#   Ai::Actions::Catalog.allowed_type?("draft_email")
#   Ai::Actions::Catalog.validate!("draft_email", payload_hash)
#   Ai::Actions::Catalog.as_system_prompt_json
#
# Notes:
# - This is not a full JSON schema validator on purpose (MVP).
# - The server must still treat all actions as "proposals" requiring human approval.

module Ai
  module Actions
    class Catalog
    Action = Struct.new(
      :type,
      :title,
      :description,
      :payload_required_keys,
      :payload_optional_keys,
      :examples,
      keyword_init: true
    )

    DEFAULT_TIMEZONE = ENV.fetch("DEFAULT_TIMEZONE", "Europe/Vienna").freeze
    DEFAULT_MORNING_HOUR = ENV.fetch("DEFAULT_MORNING_HOUR", "8").to_i

    # --- Catalog definition ---
    #
    # Keep payload keys stable. If you change them, migrate any stored actions.
    #
    # Key product rule:
    # - "Delivery" is implicit: scheduled outputs appear inside THIS app (conversation UI).
    #   Do not encode "delivery targets" in payloads.
    #
    CATALOG = [
      Action.new(
        type: "schedule_prompt",
        title: "Create scheduled prompt",
        description: "Propose a scheduled prompt that runs later on a cadence (cron/RRULE) and posts results into this app (conversation UI).",
        #
        # IMPORTANT:
        # We keep required keys to the minimum needed to schedule + run.
        # Extra preferences should be optional so the AI can propose the action ASAP.
        #
        payload_required_keys: %w[title schedule prompt_template],
        payload_optional_keys: %w[timezone sources conversation_id enabled],
        examples: [
          {
            title: "Morning news: Kurier, DerStandard, FAZ",
            schedule: "RRULE:FREQ=DAILY;BYHOUR=8;BYMINUTE=0;BYSECOND=0",
            timezone: "Europe/Vienna",
            sources: ["kurier.at", "derstandard.at", "faz.net"],
            prompt_template: "Summarize the top stories from Kurier, Der Standard, and FAZ. Provide bullets with links.",
            enabled: true
          },
          {
            title: "Daily weather brief",
            schedule: "RRULE:FREQ=DAILY;BYHOUR=8;BYMINUTE=0;BYSECOND=0",
            timezone: "Europe/Vienna",
            sources: ["weather"],
            prompt_template: "Give me a short weather brief for Vienna (today + tomorrow): temperature range, precipitation, wind, and any warnings. Bullet points.",
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
        type: "suggest_additional_context",
        title: "Suggest additional context",
        description: "Offer optional context that could improve the next output version.",
        payload_required_keys: %w[suggestions],
        payload_optional_keys: %w[title why],
        examples: [
          {
            title: "Could improve the next revision",
            why: "A few specifics would tighten the result.",
            suggestions: [
              "Target audience (execs, analysts, or customers)",
              "Preferred depth (quick summary vs detailed breakdown)",
              "Time horizon to prioritize (next 30/90/365 days)"
            ]
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
          { questions: ["Which city should I use for the weather?", "What time in the morning (default is 08:00)?"] }
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

    # Alias for callers that prefer "allowed_*" naming.
    def self.allowed_types
      types
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

      case type.to_s
      when "request_missing_info"
        validate_string_array!(payload["questions"], field: "questions", min: 1, max: 3)
      when "suggest_additional_context"
        validate_string_array!(payload["suggestions"], field: "suggestions", min: 1, max: 4)
      end

      true
    end

    # Normalize payload keys to strings and keep only allowed keys.
    # Also applies safe defaults for some action types (MVP).
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

      apply_defaults!(type.to_s, normalized)
      normalized
    end

    def self.apply_defaults!(type, payload)
      case type
      when "schedule_prompt"
        # If AI omitted timezone, default to configured app default (typically user timezone later).
        payload["timezone"] = DEFAULT_TIMEZONE if blankish?(payload["timezone"])

        # If AI omitted enabled, default to true (user can disable on approval UI).
        payload["enabled"] = true if payload.key?("enabled") == false

        # If user asked for "morning" but no schedule was provided, this still won't pass validate!
        # We do not guess schedules here beyond simple defaults. The extractor should set schedule.
      end
    end
    private_class_method :apply_defaults!

    def self.blankish?(val)
      val.nil? || (val.respond_to?(:empty?) && val.empty?) || val.to_s.strip.empty?
    end
    private_class_method :blankish?

    def self.validate_string_array!(value, field:, min:, max:)
      unless value.is_a?(Array)
        raise ArgumentError, "Invalid payload: #{field} must be an array"
      end

      normalized = value.map { |v| v.to_s.strip }.reject(&:empty?)
      if normalized.length < min || normalized.length > max
        raise ArgumentError, "Invalid payload: #{field} must have #{min}-#{max} non-empty entries"
      end
    end
    private_class_method :validate_string_array!

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
        end,
        defaults: {
          timezone: DEFAULT_TIMEZONE,
          morning_hour: DEFAULT_MORNING_HOUR,
          delivery: "Results appear inside this app (conversation UI); do not ask about delivery channels."
        }
      }
    end

    # ----------------------------
    # Prompt helpers (two-pass)
    # ----------------------------
    #
    # Your architecture:
    # - Pass 1 streams plain text (no JSON contract)
    # - Pass 2 extracts proposed actions as strict JSON (non-streamed)
    #

    # Pass 2: Strict JSON extraction prompt (actions only)
    def self.extraction_system_prompt
      <<~PROMPT
        You are extracting PROPOSED ACTIONS for a human-in-the-loop system.

        Core rules:
        - You MUST NOT execute actions. You may only PROPOSE actions.
        - Only propose action types from the catalog below.
        - Prefer proposing a concrete action using sensible defaults rather than asking follow-up questions in chat text.
        - Use "request_missing_info" ONLY when you cannot form a VALID payload for any allowed action, even with defaults.
        - Payload keys must match the required/optional keys exactly (no extras).

        Product rules:
        - Delivery is implicit: scheduled prompt results appear inside THIS app (conversation UI).
          Do NOT propose actions that ask where to deliver content.

        Output MUST be valid JSON ONLY (no markdown fences, no extra text) with this exact shape:
        [
          { "type": "...", "payload": { ... }, "metadata": { ... } }
        ]

        Defaulting guidance:
        - If the user message is only an acknowledgement/closure (e.g. "thanks", "great", "ok"), output [].
        - If additional context could improve the next output, prefer "suggest_additional_context" with 1-4 concrete suggestions.
        - Suggestions must add new, actionable context (audience, scope, constraints, format, examples).
          Do NOT suggest reconfirming what is already known, do NOT output "OK?" confirmations,
          and do NOT wrap suggestion text in quotes.
        - If the user requests recurring behavior (daily/morning/weekly/etc.), propose "schedule_prompt".
        - For "each morning" with no time: default to 08:00 (local timezone).
        - If location is missing for weather, still propose "schedule_prompt" if you can, and ask for ONE missing field only if needed.
        - Avoid proposing "request_missing_info" when a valid "schedule_prompt" payload can be produced.

        Notes:
        - "metadata" is optional; if present it must be an object.
        - If no actions apply, output [].

        Catalog (JSON):
        #{JSON.generate(as_system_prompt_json)}
      PROMPT
    end

    # Backward-compatible name: treat this as the Pass 2 extraction prompt.
    # (The older single-pass shape is intentionally removed to match the two-pass design.)
    def self.system_prompt_block
      extraction_system_prompt
    end
    end
  end
end
