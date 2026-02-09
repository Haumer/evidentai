require "test_helper"
require "securerandom"

class ArtifactsControllerTest < ActionDispatch::IntegrationTest
  test "show renders artifact workspace instead of redirecting to chat" do
    artifact, chat, user = build_artifact_with_membership
    sign_in_as(user)

    get artifact_path(artifact)

    assert_response :success
    assert_select "h1", text: "Triggers"
    assert_select "aside.artifact-pane"
    assert_select "section.artifact-triggers-pane"
    assert_select "a[href='#{chat_path(chat)}']", text: "Open chat"
  end

  private

  def build_artifact_with_membership
    company = Company.create!(name: "Acme", slug: "acme-#{SecureRandom.hex(4)}", status: "active")
    user = User.create!(email: "user-#{SecureRandom.hex(4)}@example.com", password: "password123")
    Membership.create!(company: company, user: user, role: "owner", status: "active")
    chat = Chat.create!(company: company, created_by: user, title: "Report chat", status: "active")
    artifact = Artifact.create!(company: company, created_by: user, chat: chat, content: "<html></html>", status: "ready")
    [artifact, chat, user]
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
