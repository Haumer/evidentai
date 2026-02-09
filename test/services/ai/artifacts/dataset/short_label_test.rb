require "test_helper"

class AiArtifactsDatasetShortLabelTest < ActiveSupport::TestCase
  test "removes trailing parenthetical detail" do
    label = Ai::Artifacts::Dataset::ShortLabel.call(
      "Vienna, Austria - 7-day forecast (daily highs/lows and summary)",
      fallback: "Sheet 1"
    )

    assert_equal "Vienna, Austria - 7-day forecast", label
  end

  test "falls back when name is blank" do
    label = Ai::Artifacts::Dataset::ShortLabel.call("", fallback: "Sheet 2")

    assert_equal "Sheet 2", label
  end
end
