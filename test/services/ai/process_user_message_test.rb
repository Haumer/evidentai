require "test_helper"

class AiProcessUserMessageTest < ActiveSupport::TestCase
  FakeUserMessage = Struct.new(:chat, :id)
  StepDouble = Struct.new(:callback, :context) do
    def call
      callback.call(context)
    end
  end

  test "skips artifact step when intent says no artifact update" do
    calls = run_with_step_doubles(intent_meta: { should_generate_artifact: false })

    assert_equal [:chat, :intent, :actions], calls
  end

  test "runs artifact step when intent metadata is missing (fail-open)" do
    calls = run_with_step_doubles(intent_meta: nil)

    assert_equal [:chat, :intent, :artifact, :actions], calls
  end

  private

  def run_with_step_doubles(intent_meta:)
    user_message = FakeUserMessage.new(Object.new, 123)
    calls = []

    Ai::ProcessUserMessage::ChatReplyStep.stub :new, step_stub(calls, :chat) do
      Ai::ProcessUserMessage::IntentStep.stub :new, step_stub(calls, :intent) { |ctx| ctx.meta = intent_meta } do
        Ai::ProcessUserMessage::ArtifactStep.stub :new, step_stub(calls, :artifact) do
          Ai::ProcessUserMessage::ActionsStep.stub :new, step_stub(calls, :actions) do
            Ai::ProcessUserMessage.new(user_message: user_message, context: "context").call
          end
        end
      end
    end

    calls
  end

  def step_stub(calls, name, &after_call)
    lambda do |context:|
      StepDouble.new(
        lambda do |ctx|
          calls << name
          after_call.call(ctx) if after_call
        end,
        context
      )
    end
  end
end
