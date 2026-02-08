# app/models/ai_message.rb
class AiMessage < ApplicationRecord
  belongs_to :user_message

  has_one :ai_message_meta, dependent: :destroy

  has_many :proposed_actions, dependent: :destroy
  has_many :attachments, as: :attachable, dependent: :destroy

  # IMPORTANT:
  # During streaming, content may be temporarily empty.
  # We only require content once the message is finalized.
  validates :content, presence: true, unless: :streaming?

  # Convenience: conversational text (left panel)
  def text
    content.is_a?(Hash) ? content["text"].to_s : ""
  end

  def streaming?
    status == "streaming"
  end
end
