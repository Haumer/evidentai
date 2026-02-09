require "test_helper"

class AiActionsExtractProposedTest < ActiveSupport::TestCase
  FakeAiMessage = Struct.new(:content)
  FakeUser = Struct.new(:context_suggestions_enabled) do
    def context_suggestions_enabled?
      context_suggestions_enabled != false
    end
  end
  FakeChat = Struct.new(:context_suggestions_enabled) do
    def context_suggestions_enabled?
      context_suggestions_enabled != false
    end
  end
  FakeUserMessage = Struct.new(:instruction, :ai_message, :chat, :created_by)

  test "filters context suggestion action type when include_context_suggestions is false" do
    extractor = build_extractor(include_context_suggestions: false, chat_enabled: true, user_enabled: true)
    allowed = extractor.send(:allowed_types_for_request)

    assert_not_includes allowed, "suggest_additional_context"
  end

  test "keeps context suggestion action type when enabled at call + settings" do
    extractor = build_extractor(include_context_suggestions: true, chat_enabled: true, user_enabled: true)
    allowed = extractor.send(:allowed_types_for_request)

    assert_includes allowed, "suggest_additional_context"
  end

  test "filters context suggestion action type when chat setting is disabled" do
    extractor = build_extractor(include_context_suggestions: true, chat_enabled: false, user_enabled: true)
    allowed = extractor.send(:allowed_types_for_request)

    assert_not_includes allowed, "suggest_additional_context"
  end

  private

  def build_extractor(include_context_suggestions:, chat_enabled:, user_enabled:)
    user_message = FakeUserMessage.new(
      "hello",
      FakeAiMessage.new({ "text" => "ok" }),
      FakeChat.new(chat_enabled),
      FakeUser.new(user_enabled)
    )

    Ai::Actions::ExtractProposed.new(
      user_message: user_message,
      context: "",
      include_context_suggestions: include_context_suggestions
    )
  end
end
