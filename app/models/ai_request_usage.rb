class AiRequestUsage < ApplicationRecord
  belongs_to :company
  belongs_to :chat
  belongs_to :user_message, optional: true
  belongs_to :ai_message, optional: true

  validates :request_kind, presence: true
  validates :provider, presence: true
end
