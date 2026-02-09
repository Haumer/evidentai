class ExtractActionsJob < ApplicationJob
  queue_as :default

  def perform(user_message_id)
    user_message = UserMessage.find_by(id: user_message_id)
    return unless user_message
    include_context_suggestions = suggestions_enabled?(user_message)

    settings = user_message.settings.is_a?(Hash) ? user_message.settings : {}
    turns = (settings["context_turns"] || Ai::Context::BuildContext::DEFAULT_TURNS).to_i
    max_chars = (settings["context_max_chars"] || Ai::Context::BuildContext::DEFAULT_MAX_CHARS).to_i

    context = Ai::Context::BuildContext.new(
      chat: user_message.chat,
      exclude_user_message_id: user_message.id,
      turns: turns,
      max_chars: max_chars
    ).call

    run_context = Ai::ProcessUserMessage::Context.new(
      user_message: user_message,
      context_text: context,
      model: Ai::ProcessUserMessage::DEFAULT_MODEL,
      provider: Ai::ProcessUserMessage::DEFAULT_PROVIDER
    )

    Ai::ProcessUserMessage::ActionsStep.new(
      context: run_context,
      include_context_suggestions: include_context_suggestions
    ).call
  rescue => e
    Rails.logger.warn("[ExtractActionsJob] #{e.class}: #{e.message}")
  end

  private

  def suggestions_enabled?(user_message)
    chat = user_message.chat
    user = user_message.created_by

    chat_enabled =
      if chat.respond_to?(:context_suggestions_enabled?)
        chat.context_suggestions_enabled?
      elsif chat.respond_to?(:context_suggestions_enabled)
        chat.context_suggestions_enabled != false
      else
        true
      end

    account_enabled =
      if user.respond_to?(:context_suggestions_enabled?)
        user.context_suggestions_enabled?
      elsif user.respond_to?(:context_suggestions_enabled)
        user.context_suggestions_enabled != false
      else
        true
      end

    chat_enabled && account_enabled
  rescue
    true
  end
end
