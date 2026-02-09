require "test_helper"
require "securerandom"

class Admin::AiUsageControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "index is admin-only" do
    user = User.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123", admin: false)
    sign_in user

    get admin_ai_usage_path

    assert_redirected_to root_path
  end

  test "index shows usage across all companies for admin" do
    admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", admin: true)
    sign_in admin

    chat_a = create_usage_row!(company_name: "Acme")
    chat_b = create_usage_row!(company_name: "Beta")

    get admin_ai_usage_path

    assert_response :success
    assert_includes @response.body, "Scope: <strong>All companies, all users</strong>"
    assert_includes @response.body, "Chat ##{chat_a.id}"
    assert_includes @response.body, "Chat ##{chat_b.id}"
  end

  test "retry run works for admin across companies" do
    admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", admin: true)
    sign_in admin

    company = Company.create!(name: "Gamma", slug: "gamma-#{SecureRandom.hex(4)}", status: "active")
    actor = User.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123")
    chat = Chat.create!(company: company, created_by: actor, status: "active", title: "Retry target")
    user_message = UserMessage.create!(
      company: company,
      created_by: actor,
      chat: chat,
      instruction: "retry this",
      status: "failed"
    )

    called_with_id = nil

    Ai::Chat::RetryUserMessage.stub(:call, ->(user_message:) { called_with_id = user_message.id }) do
      post admin_ai_usage_retry_run_path, params: { user_message_id: user_message.id }
    end

    assert_equal user_message.id, called_with_id
    assert_redirected_to admin_ai_usage_path
  end

  private

  def create_usage_row!(company_name:)
    company = Company.create!(
      name: company_name,
      slug: "#{company_name.downcase}-#{SecureRandom.hex(4)}",
      status: "active"
    )
    user = User.create!(email: "#{company_name.downcase}-#{SecureRandom.hex(4)}@example.com", password: "password123")
    chat = Chat.create!(company: company, created_by: user, status: "active", title: "#{company_name} chat")

    AiRequestUsage.create!(
      company: company,
      chat: chat,
      request_kind: "chat_reply",
      provider: "openai",
      model: "gpt-5",
      requested_at: Time.current,
      status: "completed",
      total_tokens: 123,
      input_tokens: 45,
      output_tokens: 78,
      total_cost_usd: 0.01
    )

    chat
  end
end
