require "test_helper"

class AiProcessUserMessageIntentStepTest < ActiveSupport::TestCase
  test "applies suggested title from intent metadata" do
    company = Company.create!(name: "Acme", slug: "acme-#{SecureRandom.hex(4)}", status: "active")
    user = User.create!(email: "intent-step-#{SecureRandom.hex(4)}@example.com", password: "password123")
    chat = Chat.create!(company: company, created_by: user, status: "active")
    user_message = UserMessage.create!(
      company: company,
      created_by: user,
      chat: chat,
      instruction: "show me a weather forecast",
      status: "done"
    )
    ai_message = user_message.create_ai_message!(content: { "text" => "On it." }, status: "done")

    context = Ai::ProcessUserMessage::Context.new(
      user_message: user_message,
      context_text: "ctx",
      model: "gpt-5.2",
      provider: "openai"
    )
    context.ai_message = ai_message
    context.meta = {
      suggested_title: "Weather Forecast for Vienna",
      should_generate_artifact: true,
      needs_sources: true,
      suggest_web_search: true,
      flags: {}
    }

    broadcaster = Struct.new(:calls) do
      def replace(*)
        self.calls ||= 0
        self.calls += 1
      end
    end.new(0)

    Ai::Chat::Broadcast::TitleBroadcaster.stub :new, broadcaster do
      Ai::ProcessUserMessage::IntentStep.new(context: context).send(:apply_title_from_intent!)
    end

    chat.reload
    assert_equal "Weather Forecast for Vienna", chat.title
    assert chat.title_generated_at.present?
    assert_equal 1, broadcaster.calls
  end
end
