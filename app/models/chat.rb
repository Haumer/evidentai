# app/models/chat.rb
class Chat < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: "User"

  has_many :user_messages, dependent: :destroy
  has_many :artifacts, dependent: :destroy

  def title_locked_by_user?
    title_set_by_user?
  end

  def can_auto_generate_title?
    !title_locked_by_user? && title.blank?
  end
end
