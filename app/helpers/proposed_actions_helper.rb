module ProposedActionsHelper
  GENERIC_CONTEXT_PATTERN = /
    \b(
      reason\ for|
      preferred\ appointment\ window|
      specific\ symptoms|
      prescription\ renewal|
      urgency|
      target\ audience|
      preferred\ depth|
      time\ horizon
    )\b
  /ix

  def proposed_action_summary(action)
    case action.action_type
    when "draft_email"
      <<~TEXT
        Draft an email
        Subject: #{action.payload["subject"]}
      TEXT

    when "schedule_prompt"
      <<~TEXT
        Schedule a prompt
        Title: #{action.payload["title"]}
        Schedule: #{action.payload["schedule"]}
        Timezone: #{action.payload["timezone"]}
      TEXT

    when "create_task"
      <<~TEXT
        Create a task
        Title: #{action.payload["title"]}
      TEXT

    when "request_missing_info"
      questions = Array(action.payload["questions"]).map { |q| "• #{q}" }.join("\n")
      <<~TEXT
        Needs more information:
        #{questions}
      TEXT

    else
      "Proposed action: #{action.action_type}"
    end
  end

  def extract_concrete_context_suggestions(actions:, current_instruction:, limit: 2)
    suggestions =
      Array(actions).flat_map do |action|
        payload = action.respond_to?(:payload) && action.payload.is_a?(Hash) ? action.payload : {}
        raw = Array(payload["suggestions"]) + Array(payload["questions"])

        if raw.empty?
          fallback =
            payload["prompt_template"].to_s.presence ||
            payload["title"].to_s.presence ||
            payload["subject"].to_s.presence
          raw << fallback if fallback.present?
        end

        raw
      end

    normalized_instruction = current_instruction.to_s.squish.downcase

    suggestions
      .map { |value| normalize_context_suggestion(value) }
      .reject(&:blank?)
      .reject { |value| value.downcase == normalized_instruction }
      .reject { |value| low_signal_context_suggestion?(value) }
      .select { |value| concrete_context_suggestion?(value) }
      .uniq
      .first(limit)
  end

  private

  def normalize_context_suggestion(value)
    value.to_s.tr("“”", "\"").tr("‘’", "'")
      .squish
      .sub(/\A["']+/, "")
      .sub(/["']+\z/, "")
      .sub(/\s+["']\z/, "")
      .strip
  end

  def low_signal_context_suggestion?(value)
    s = value.to_s.downcase
    return true if s.blank?
    return true if s.include?("single-sentence confirmation")
    return true if s.match?(/\bok\?\s*\z/)
    return true if s.match?(/\bconfirm(?:ation)?\b/) && s.match?(/\b(already|current|existing|same|above|this)\b/)
    return true if s.match?(/\[[^\]]+\]|\{[^}]+\}|<[^>]+>/) # placeholders like [DATE]
    return true if s.match?(/\b(e\.g\.|for example|such as)\b/)
    return true if s.match?(/\([^)]*(\/|,|\bor\b)[^)]*\)/)
    return true if s.match?(GENERIC_CONTEXT_PATTERN)

    false
  end

  def concrete_context_suggestion?(value)
    s = value.to_s.strip
    return false if s.length < 16
    return false unless s.match?(/\?\z|\.\z/)
    return false if s.split.size < 4

    true
  end
end
