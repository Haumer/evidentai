class SubmitUserMessageJob < ApplicationJob
  queue_as :default

  def perform(user_message_id)
    user_message = UserMessage.find(user_message_id)
    chat = user_message.chat
    raise "UserMessage has no chat" unless chat

    # ---- Single entry point ----
    Ai::ProcessUserMessage.new(user_message: user_message).call
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
