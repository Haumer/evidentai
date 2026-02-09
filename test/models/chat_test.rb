require "test_helper"
require "securerandom"

class ChatTest < ActiveSupport::TestCase
  test "untouched_for_new_chat is true for default empty chat" do
    chat = build_chat

    assert chat.untouched_for_new_chat?
  end

  test "untouched_for_new_chat is false when title was set by user" do
    chat = build_chat(title: "Ideas", title_set_by_user: true)

    refute chat.untouched_for_new_chat?
  end

  test "untouched_for_new_chat is false when a user message exists" do
    chat = build_chat
    UserMessage.create!(
      company: chat.company,
      created_by: chat.created_by,
      chat: chat,
      instruction: "hello",
      status: "queued"
    )

    refute chat.reload.untouched_for_new_chat?
  end

  private

  def build_chat(title: nil, title_set_by_user: false)
    company = Company.create!(name: "Acme", slug: "acme-#{SecureRandom.hex(4)}", status: "active")
    user = User.create!(email: "chat-#{SecureRandom.hex(4)}@example.com", password: "password123")
    Chat.create!(
      company: company,
      created_by: user,
      status: "active",
      title: title,
      title_set_by_user: title_set_by_user
    )
  end
end
