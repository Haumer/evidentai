require "test_helper"

class AiChatAssumedDefaultsTest < ActiveSupport::TestCase
  test "adds travel-radius default when request implies nearby scope without explicit radius" do
    defaults = Ai::Chat::AssumedDefaults.call(
      instruction: "golf locations around vienna",
      chat_history_text: "U1: golf locations around vienna"
    )

    assert_equal ["a 60-minute travel radius"], defaults
  end

  test "does not add travel-radius default when explicit radius is present" do
    defaults = Ai::Chat::AssumedDefaults.call(
      instruction: "golf locations 90 mins around vienna",
      chat_history_text: "U1: golf locations around vienna\nU2: austria\nU3: 90mins around vienna"
    )

    assert_equal [], defaults
  end
end
