require "test_helper"
require "securerandom"

class ArtifactTriggerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "enqueue_run! creates queued message and enqueues processing" do
    company, user, chat, artifact = build_base_records
    trigger = ArtifactTrigger.create!(
      company: company,
      created_by: user,
      chat: chat,
      artifact: artifact,
      name: "Email trigger",
      trigger_type: "email",
      status: "active",
      instruction_template: "Update the weekly report",
      context_turns: 6,
      context_max_chars: 4000
    )

    clear_enqueued_jobs

    user_message = nil
    assert_difference("UserMessage.count", 1) do
      assert_enqueued_with(job: SubmitUserMessageJob) do
        user_message = trigger.enqueue_run!(
          input_text: "Body from inbound email",
          fired_by: user,
          context_turns: 12,
          context_max_chars: 9000,
          source: "email"
        )
      end
    end

    assert_not_nil user_message
    assert_equal chat.id, user_message.chat_id
    assert_equal "queued", user_message.status
    assert_equal 12, user_message.settings["context_turns"]
    assert_equal 9000, user_message.settings["context_max_chars"]
    assert_match "Update the weekly report", user_message.instruction
    assert_match "Body from inbound email", user_message.instruction

    trigger.reload
    assert_equal 1, trigger.fired_count
    assert trigger.last_fired_at.present?
  end

  test "enqueue_run! falls back to latest chat prompt when template is blank" do
    company, user, chat, artifact = build_base_records

    chat.user_messages.create!(
      company: company,
      created_by: user,
      instruction: "Generate updated KPI dashboard",
      status: "done"
    )

    trigger = ArtifactTrigger.create!(
      company: company,
      created_by: user,
      chat: chat,
      artifact: artifact,
      name: "Manual rerun",
      trigger_type: "manual",
      status: "active",
      instruction_template: "",
      context_turns: 6,
      context_max_chars: 4000
    )

    instruction = trigger.build_instruction(input_text: "new csv uploaded", source: "file")
    assert_match "Generate updated KPI dashboard", instruction
    assert_match "new csv uploaded", instruction
  end

  test "paused trigger cannot run" do
    company, user, chat, artifact = build_base_records
    trigger = ArtifactTrigger.create!(
      company: company,
      created_by: user,
      chat: chat,
      artifact: artifact,
      name: "Paused trigger",
      trigger_type: "api",
      status: "paused",
      context_turns: 6,
      context_max_chars: 4000
    )

    error = assert_raises(ArgumentError) do
      trigger.enqueue_run!(input_text: "x", fired_by: user)
    end

    assert_equal "Trigger is paused", error.message
  end

  private

  def build_base_records
    company = Company.create!(name: "Acme", slug: "acme-#{SecureRandom.hex(4)}", status: "active")
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com", password: "password123")
    chat = Chat.create!(company: company, created_by: user, title: "Trigger chat", status: "active")
    artifact = Artifact.create!(company: company, created_by: user, chat: chat, content: "<html></html>", status: "ready")
    [company, user, chat, artifact]
  end
end
