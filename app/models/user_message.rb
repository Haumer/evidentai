# app/models/user_message.rb
class UserMessage < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: "User"
  belongs_to :chat, inverse_of: :user_messages

  has_many :attachments, as: :attachable, dependent: :destroy
  has_many :ai_request_usages, dependent: :nullify
  has_one :ai_message, dependent: :destroy, inverse_of: :user_message

  validates :instruction, presence: true

  def artifact_updated?
    respond_to?(:artifact_updated_at) && artifact_updated_at.present?
  end

  def suggestions_dismissed?
    settings_hash = settings.is_a?(Hash) ? settings : {}
    settings_hash["suggestions_dismissed"] == true
  end

  def with_suggestions_dismissed(dismissed)
    settings_hash = settings.is_a?(Hash) ? settings.deep_dup : {}
    settings_hash["suggestions_dismissed"] = !!dismissed
    settings_hash
  end
end
