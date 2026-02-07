class SubmitUserMessageJob < ApplicationJob
  queue_as :default

  def perform(user_message_id)
    user_message = UserMessage.find(user_message_id)
    chat = user_message.chat
    raise "UserMessage has no chat" unless chat

    # ---- Build compact context + audit into user_message.settings ----
    settings = (user_message.settings || {}).dup
    turns = (settings["context_turns"] || 5).to_i
    max_chars = (settings["context_max_chars"] || 8_000).to_i

    context = Ai::Context::BuildContext.new(
      chat: chat,
      exclude_user_message_id: user_message.id,
      turns: turns,
      max_chars: max_chars
    ).call

    settings["context_used"] = context
    settings["context_used_meta"] = {
      "turns" => turns,
      "max_chars" => max_chars,
      "generated_at" => Time.current.iso8601,
      "version" => 2
    }
    user_message.update!(settings: settings)

    # ---- Single entry point ----
    Ai::RunUserMessage.new(user_message: user_message, context: context).call
  rescue => e
    begin
      UserMessage.where(id: user_message_id)
                 .update_all(status: "failed", error_message: e.message)
    rescue
      # ignore
    end
    raise
  end
end
