module Ai
  class ProcessUserMessage
    DEFAULT_MODEL = ENV.fetch("OPENAI_MODEL", "gpt-5.2").freeze
    DEFAULT_PROVIDER = ENV.fetch("AI_PROVIDER", "openai").freeze
    def initialize(user_message:, context: nil, model: DEFAULT_MODEL, provider: DEFAULT_PROVIDER)
      @run_context = Context.new(
        user_message: user_message,
        context_text: context,
        model: model,
        provider: provider
      )
    end

    def call
      ChatReplyStep.new(context: @run_context).call
      IntentStep.new(context: @run_context).call
      ActionsStep.new(context: @run_context).call
      ArtifactStep.new(context: @run_context).call if @run_context.should_generate_artifact?
    end
  end
end
