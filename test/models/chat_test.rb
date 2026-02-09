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

  test "assigns inbound_email_token when column is present" do
    skip "inbound_email_token column not present in this DB" unless Chat.column_names.include?("inbound_email_token")

    chat = build_chat

    assert chat.inbound_email_token.present?
  end

  test "preserves explicit inbound_email_token when provided" do
    skip "inbound_email_token column not present in this DB" unless Chat.column_names.include?("inbound_email_token")

    chat = build_chat(inbound_email_token: "manual-token")

    assert_equal "manual-token", chat.inbound_email_token
  end

  test "inbound_email_address includes configured domain" do
    skip "inbound_email_token column not present in this DB" unless Chat.column_names.include?("inbound_email_token")

    previous_domain = ENV["CHAT_INBOUND_EMAIL_DOMAIN"]
    ENV["CHAT_INBOUND_EMAIL_DOMAIN"] = "inbound.example.com"

    chat = build_chat(inbound_email_token: "mail-token")
    assert_equal "mail-token@inbound.example.com", chat.inbound_email_address
  ensure
    ENV["CHAT_INBOUND_EMAIL_DOMAIN"] = previous_domain
  end

  test "inbound_email_id and address fall back to token when domain missing" do
    skip "inbound_email_token column not present in this DB" unless Chat.column_names.include?("inbound_email_token")

    previous_domain = ENV["CHAT_INBOUND_EMAIL_DOMAIN"]
    ENV["CHAT_INBOUND_EMAIL_DOMAIN"] = nil

    chat = build_chat(inbound_email_token: "mail-token")
    assert_equal "mail-token", chat.inbound_email_id
    assert_equal "mail-token", chat.inbound_email_address
  ensure
    ENV["CHAT_INBOUND_EMAIL_DOMAIN"] = previous_domain
  end

  private

  def build_chat(title: nil, title_set_by_user: false, inbound_email_token: nil)
    company = Company.create!(name: "Acme", slug: "acme-#{SecureRandom.hex(4)}", status: "active")
    user = User.create!(email: "chat-#{SecureRandom.hex(4)}@example.com", password: "password123")
    attrs = {
      company: company,
      created_by: user,
      status: "active",
      title: title,
      title_set_by_user: title_set_by_user
    }
    attrs[:inbound_email_token] = inbound_email_token unless inbound_email_token.nil?

    Chat.create!(attrs)
  end
end
