require "test_helper"
require "securerandom"

class Artifacts::TriggersControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "creates and fires a trigger from artifact page" do
    artifact, user = build_artifact_with_membership
    sign_in_as(user)

    assert_difference("ArtifactTrigger.count", 1) do
      post artifact_triggers_path(artifact), params: {
        artifact_trigger: {
          name: "Manual rerun",
          trigger_type: "manual",
          status: "active",
          instruction_template: "Refresh the report",
          context_turns: 7,
          context_max_chars: 5000
        }
      }
    end

    trigger = ArtifactTrigger.order(created_at: :desc).first
    clear_enqueued_jobs

    assert_difference("UserMessage.count", 1) do
      assert_enqueued_with(job: SubmitUserMessageJob) do
        post fire_artifact_trigger_path(artifact, trigger), params: {
          input_text: "new file available",
          context_turns: 8,
          context_max_chars: 6500
        }
      end
    end

    assert_redirected_to artifact_path(artifact)
  end

  private

  def build_artifact_with_membership
    company = Company.create!(name: "Acme", slug: "acme-#{SecureRandom.hex(4)}", status: "active")
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com", password: "password123")
    Membership.create!(company: company, user: user, role: "owner", status: "active")
    chat = Chat.create!(company: company, created_by: user, title: "Report chat", status: "active")
    artifact = Artifact.create!(company: company, created_by: user, chat: chat, content: "<html></html>", status: "ready")
    [artifact, user]
  end

  def sign_in_as(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }
  end
end
