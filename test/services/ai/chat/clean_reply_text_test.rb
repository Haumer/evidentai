require "test_helper"

class AiChatCleanReplyTextTest < ActiveSupport::TestCase
  test "strips trailing internal metadata json with straight quotes" do
    input = <<~TEXT
      Sure, I can help with that.
      {"suggested_title":"Clarify user task after greeting","inferred_intent":"User acknowledged and needs to specify what they want help with"}
    TEXT

    assert_equal "Sure, I can help with that.", Ai::Chat::CleanReplyText.call(input)
  end

  test "strips trailing internal metadata json with curly quotes" do
    input = <<~TEXT
      Absolutely.
      {“suggested_title”:“Clarify user task after greeting”,“inferred_intent”:“User acknowledged and needs to specify what they want help with”}
    TEXT

    assert_equal "Absolutely.", Ai::Chat::CleanReplyText.call(input)
  end

  test "strips trailing metadata json when control-plane keys are present" do
    input = <<~TEXT
      Done. I can generate that now.
      {"should_generate_artifact":true,"needs_sources":false,"suggest_web_search":false,"flags":{}}
    TEXT

    assert_equal "Done. I can generate that now.", Ai::Chat::CleanReplyText.call(input)
  end

  test "strips trailing fenced metadata json" do
    input = <<~TEXT
      Here's the update.
      ```json
      {"suggested_title":"Weather forecast","inferred_intent":"Generate weather artifact"}
      ```
    TEXT

    assert_equal "Here's the update.", Ai::Chat::CleanReplyText.call(input)
  end

  test "strips unknown trailing json object when clearly appended on a new line" do
    input = <<~TEXT
      All set.
      {"foo":"bar"}
    TEXT

    assert_equal "All set.", Ai::Chat::CleanReplyText.call(input)
  end

  test "does not strip unrelated trailing json" do
    input = "Result payload: {\"ok\":true}"
    assert_equal input, Ai::Chat::CleanReplyText.call(input)
  end

  test "does not change plain text" do
    input = "Thanks, done."
    assert_equal input, Ai::Chat::CleanReplyText.call(input)
  end
end
