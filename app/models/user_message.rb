# app/models/user_message.rb
class UserMessage < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: "User"
  belongs_to :chat, inverse_of: :user_messages

  has_many :attachments, as: :attachable, dependent: :destroy
  has_one :ai_message, dependent: :destroy, inverse_of: :user_message

  validates :instruction, presence: true
end
