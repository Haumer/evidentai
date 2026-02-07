# app/models/chat.rb
class Chat < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: "User"

  has_many :user_messages, dependent: :destroy
  has_many :artifacts, dependent: :destroy
end
