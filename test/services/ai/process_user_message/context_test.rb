require "test_helper"

class AiProcessUserMessageContextTest < ActiveSupport::TestCase
  FakeUserMessage = Struct.new(:chat, :id, :instruction)
  FakeAiMessage = Struct.new(:text)
  FakeHistoryMessage = Struct.new(:id, :instruction, :ai_message)

  class FakeUserMessagesRelation
    attr_reader :records

    def initialize(records)
      @records = records
    end

    def where(*)
      FakeWhereProxy.new(self)
    end

    def includes(*)
      self
    end

    def order(created_at: :desc)
      self.class.new(@records.reverse)
    end

    def first
      @records.first
    end
  end

  class FakeWhereProxy
    def initialize(relation)
      @relation = relation
    end

    def not(id:)
      filtered = @relation.records.reject { |r| r.id == id }
      FakeUserMessagesRelation.new(filtered)
    end
  end

  FakeChat = Struct.new(:user_messages)

  test "should_generate_artifact? returns true when metadata is missing" do
    context = build_context
    context.meta = nil

    assert context.should_generate_artifact?
  end

  test "should_generate_artifact? returns true when intent says true" do
    context = build_context
    context.meta = { should_generate_artifact: true }

    assert context.should_generate_artifact?
  end

  test "should_generate_artifact? can recover via follow-up heuristic" do
    context = build_context
    context.meta = { should_generate_artifact: false }

    context.stub :follow_up_answer_for_artifact_request?, true do
      assert context.should_generate_artifact?
    end
  end

  test "should_generate_artifact? returns false when intent says false and heuristic fails" do
    context = build_context
    context.meta = { should_generate_artifact: false }

    context.stub :follow_up_answer_for_artifact_request?, false do
      assert_not context.should_generate_artifact?
    end
  end

  test "should_generate_artifact? is true for short follow-up that supplies missing artifact input" do
    history = [
      FakeHistoryMessage.new(1, "3 day weather forecast", FakeAiMessage.new("Sure. Which location should I use?"))
    ]
    chat = FakeChat.new(FakeUserMessagesRelation.new(history))
    user_message = FakeUserMessage.new(chat, 2, "vienna")

    context = Ai::ProcessUserMessage::Context.new(
      user_message: user_message,
      context_text: "ctx",
      model: "gpt-5.2",
      provider: "openai"
    )
    context.meta = { should_generate_artifact: false }

    assert context.should_generate_artifact?
  end

  test "should_generate_artifact? is true for concise clarification even without a prior assistant question" do
    history = [
      FakeHistoryMessage.new(1, "Golf locations around Vienna", FakeAiMessage.new("Understood, I will work on golf locations around Vienna."))
    ]
    chat = FakeChat.new(FakeUserMessagesRelation.new(history))
    user_message = FakeUserMessage.new(chat, 2, "austria")

    context = Ai::ProcessUserMessage::Context.new(
      user_message: user_message,
      context_text: "ctx",
      model: "gpt-5.2",
      provider: "openai"
    )
    context.meta = { should_generate_artifact: false }

    assert context.should_generate_artifact?
  end

  test "should_generate_artifact? is true for longer follow-up when an artifact request already exists" do
    history = [
      FakeHistoryMessage.new(1, "Golf locations around Vienna", FakeAiMessage.new("Understood, I will work on golf locations around Vienna."))
    ]
    chat = FakeChat.new(FakeUserMessagesRelation.new(history))
    user_message = FakeUserMessage.new(chat, 2, "please prioritize public courses and include pricing")

    context = Ai::ProcessUserMessage::Context.new(
      user_message: user_message,
      context_text: "ctx",
      model: "gpt-5.2",
      provider: "openai"
    )
    context.meta = { should_generate_artifact: false }

    assert context.should_generate_artifact?
  end

  test "should_generate_artifact? stays false for courtesy-only follow-up" do
    history = [
      FakeHistoryMessage.new(1, "Golf locations around Vienna", FakeAiMessage.new("Understood, I will work on golf locations around Vienna."))
    ]
    chat = FakeChat.new(FakeUserMessagesRelation.new(history))
    user_message = FakeUserMessage.new(chat, 2, "thanks")

    context = Ai::ProcessUserMessage::Context.new(
      user_message: user_message,
      context_text: "ctx",
      model: "gpt-5.2",
      provider: "openai"
    )
    context.meta = { should_generate_artifact: false }

    assert_not context.should_generate_artifact?
  end

  test "should_generate_artifact? stays false for short follow-up on non-artifact chat" do
    history = [
      FakeHistoryMessage.new(1, "hi", FakeAiMessage.new("Where are you based?"))
    ]
    chat = FakeChat.new(FakeUserMessagesRelation.new(history))
    user_message = FakeUserMessage.new(chat, 2, "vienna")

    context = Ai::ProcessUserMessage::Context.new(
      user_message: user_message,
      context_text: "ctx",
      model: "gpt-5.2",
      provider: "openai"
    )
    context.meta = { should_generate_artifact: false }

    assert_not context.should_generate_artifact?
  end

  private

  def build_context
    user_message = FakeUserMessage.new(Object.new, 123, "vienna")
    Ai::ProcessUserMessage::Context.new(
      user_message: user_message,
      context_text: "ctx",
      model: "gpt-5.2",
      provider: "openai"
    )
  end
end
