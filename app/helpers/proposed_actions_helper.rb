module ProposedActionsHelper
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
end
