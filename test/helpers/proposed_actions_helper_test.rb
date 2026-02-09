require "test_helper"

class ProposedActionsHelperTest < ActiveSupport::TestCase
  include ProposedActionsHelper

  FakeAction = Struct.new(:payload)

  test "filters generic field-label context suggestions" do
    actions = [
      FakeAction.new(
        {
          "suggestions" => [
            "Reason for the appointment (check-up, specific symptoms, follow-up, prescription renewal)",
            "Preferred appointment window (e.g., mornings/afternoons; specific dates) and urgency"
          ]
        }
      )
    ]

    suggestions = extract_concrete_context_suggestions(actions: actions, current_instruction: "")

    assert_equal [], suggestions
  end

  test "filters placeholder suggestion templates" do
    actions = [
      FakeAction.new({ "suggestions" => ["Do you have time [TIMESLOT] on [DATE]?"] })
    ]

    suggestions = extract_concrete_context_suggestions(actions: actions, current_instruction: "")

    assert_equal [], suggestions
  end

  test "keeps concrete suggestions and removes current instruction duplicates" do
    actions = [
      FakeAction.new(
        {
          "suggestions" => [
            "Do you have time Tuesday at 10:00 or Thursday at 14:00?",
            "Should I focus this summary on churn reduction or revenue growth?"
          ]
        }
      )
    ]

    suggestions = extract_concrete_context_suggestions(
      actions: actions,
      current_instruction: "Should I focus this summary on churn reduction or revenue growth?"
    )

    assert_equal ["Do you have time Tuesday at 10:00 or Thursday at 14:00?"], suggestions
  end
end
