require "test_helper"

class AiArtifactsComposeUpdateMessagesTest < ActiveSupport::TestCase
  FakeUserMessage = Struct.new(:instruction)

  test "includes available_data payload when present" do
    messages = Ai::Artifacts::ComposeUpdateMessages.messages(
      FakeUserMessage.new("Show Austria GDP trend"),
      current_artifact_text: "<html></html>",
      chat_history: "U1: Show Austria GDP trend",
      available_data: {
        "as_of_date" => "2026-02-09",
        "dataset" => {
          "version" => 1,
          "datasets" => [
            {
              "name" => "Austria GDP",
              "schema" => ["year", "gdp_usd"],
              "rows" => [[2022, 500.1], [2023, 510.2]]
            }
          ]
        }
      }
    )

    content = messages.last[:content].to_s

    assert_includes content, "AVAILABLE_DATA:"
    assert_includes content, "CHAT_HISTORY:\nU1: Show Austria GDP trend"
    assert_includes content, "\"as_of_date\": \"2026-02-09\""
    assert_includes content, "\"schema\": ["
  end

  test "uses none marker when available_data is missing" do
    messages = Ai::Artifacts::ComposeUpdateMessages.messages(
      FakeUserMessage.new("Summarize this"),
      current_artifact_text: "",
      chat_history: nil,
      available_data: nil
    )

    assert_includes messages.last[:content].to_s, "CHAT_HISTORY:\n(none)"
    assert_includes messages.last[:content].to_s, "AVAILABLE_DATA:\n(none)"
  end
end
