require "test_helper"
require "securerandom"

class AiChatRetryUserMessageTest < ActiveSupport::TestCase
  test "resets failed run state and requeues the same user message" do
    user_message = build_failed_user_message
    queued_ids = []

    SubmitUserMessageJob.stub :perform_later, ->(id) { queued_ids << id } do
      Ai::Chat::RetryUserMessage.call(user_message: user_message)
    end

    user_message.reload
    ai_message = user_message.ai_message

    assert_equal "queued", user_message.status
    assert_nil user_message.error_message
    assert_equal "streaming", ai_message.status
    assert_equal({}, ai_message.content)
    assert_equal [user_message.id], queued_ids
    assert_equal 0, ai_message.proposed_actions.count
    assert_nil ai_message.ai_message_meta
  end

  test "rejects retry while run is in progress" do
    user_message = build_failed_user_message
    user_message.update!(status: "running")

    error = assert_raises(ArgumentError) do
      Ai::Chat::RetryUserMessage.call(user_message: user_message)
    end

    assert_equal "Run already in progress", error.message
  end

  private

  def build_failed_user_message
    company = Company.create!(name: "Acme", slug: "acme-#{SecureRandom.hex(4)}", status: "active")
    user = User.create!(email: "retry-#{SecureRandom.hex(4)}@example.com", password: "password123")
    chat = Chat.create!(company: company, created_by: user, status: "active", title: "Retry run")

    user_message = UserMessage.create!(
      company: company,
      created_by: user,
      chat: chat,
      instruction: "please generate output",
      status: "failed",
      error_message: "old raw failure"
    )

    ai_message = user_message.create_ai_message!(content: { "text" => "old text" }, status: "failed")
    ai_message.create_ai_message_meta!(
      suggested_title: "Old title",
      should_generate_artifact: true,
      needs_sources: false,
      suggest_web_search: false,
      payload_json: {},
      flags_json: {}
    )
    ai_message.proposed_actions.create!(action_type: "web_search_fetch", payload: { "query" => "x" }, metadata: {})

    user_message
  end
end
