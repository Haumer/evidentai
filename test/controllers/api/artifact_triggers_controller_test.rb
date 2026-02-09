require "test_helper"
require "securerandom"

class Api::ArtifactTriggersControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "fires trigger with valid bearer token" do
    trigger = build_trigger(trigger_type: "api")

    clear_enqueued_jobs

    assert_difference("UserMessage.count", 1) do
      assert_enqueued_with(job: SubmitUserMessageJob) do
        post fire_api_artifact_trigger_path(trigger),
             params: { input_text: "payload from external system", context_turns: 9, context_max_chars: 7000 },
             headers: { "Authorization" => "Bearer #{trigger.api_token}" },
             as: :json
      end
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["queued"]

    user_message = UserMessage.order(created_at: :desc).first
    assert_equal 9, user_message.settings["context_turns"]
    assert_equal 7000, user_message.settings["context_max_chars"]
    assert_match "payload from external system", user_message.instruction
  end

  test "returns unauthorized for invalid token" do
    trigger = build_trigger(trigger_type: "api")

    assert_no_difference("UserMessage.count") do
      post fire_api_artifact_trigger_path(trigger),
           params: { input_text: "payload from external system" },
           headers: { "Authorization" => "Bearer wrong-token" },
           as: :json
    end

    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_equal "unauthorized", body["error"]
  end

  private

  def build_trigger(trigger_type:)
    company = Company.create!(name: "Acme", slug: "acme-#{SecureRandom.hex(4)}", status: "active")
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com", password: "password123")
    chat = Chat.create!(company: company, created_by: user, title: "Trigger chat", status: "active")
    artifact = Artifact.create!(company: company, created_by: user, chat: chat, content: "<html></html>", status: "ready")

    ArtifactTrigger.create!(
      company: company,
      created_by: user,
      chat: chat,
      artifact: artifact,
      name: "API trigger",
      trigger_type: trigger_type,
      status: "active",
      instruction_template: "Refresh artifact",
      context_turns: 6,
      context_max_chars: 4000
    )
  end
end
