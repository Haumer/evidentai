require "test_helper"

class AiChatConfirmCurrentRequestTest < ActiveSupport::TestCase
  test "keeps a single confirmation sentence when already valid" do
    out = Ai::Chat::ConfirmCurrentRequest.call(
      text: "Understood, I will create a 3 day forecast for Vienna.",
      instruction: "3 day weather forecast for Vienna"
    )

    assert_equal "Understood, I will create a 3 day forecast for Vienna.", out
  end

  test "falls back when first sentence is a question" do
    out = Ai::Chat::ConfirmCurrentRequest.call(
      text: "Which city should I use?",
      instruction: "3 day weather forecast for Vienna"
    )

    assert_equal "Understood, I will work on 3 day weather forecast for Vienna.", out
  end

  test "strips trailing metadata and keeps first sentence only" do
    out = Ai::Chat::ConfirmCurrentRequest.call(
      text: "Sure, working on it. Next, tell me your audience. {\"suggested_title\":\"x\",\"inferred_intent\":\"y\"}",
      instruction: "write me a plan"
    )

    assert_equal "Sure, working on it.", out
  end
end
