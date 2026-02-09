require "test_helper"

class AiChatHumanizeErrorTest < ActiveSupport::TestCase
  test "maps quota errors to a clear billing/limits message" do
    raw = "You exceeded your current quota, please check your plan and billing details. For more information on this error, read the docs: https://platform.openai.com/docs/guides/error-codes/api-errors."
    message = Ai::Chat::HumanizeError.call(raw)

    assert_includes message, "API quota is exhausted"
    refute_includes message, "platform.openai.com/docs"
  end

  test "maps rate limits to retry guidance" do
    message = Ai::Chat::HumanizeError.call("Rate limit exceeded (429)")
    assert_includes message, "rate limit"
  end

  test "falls back to generic provider error for unknown failures" do
    message = Ai::Chat::HumanizeError.call("weird provider state")
    assert_includes message, "AI provider error"
    assert_includes message, "weird provider state"
  end
end
