# app/models/chat.rb
class Chat < ApplicationRecord
  UNTITLED_TITLES = ["untitled", "untitled chat"].freeze

  belongs_to :company
  belongs_to :created_by, class_name: "User"

  has_many :user_messages, dependent: :destroy
  has_many :artifacts, dependent: :destroy
  has_many :data_source_caches, dependent: :destroy

  def title_locked_by_user?
    title_set_by_user?
  end

  def title_effectively_untitled?
    normalized = title.to_s.strip.downcase
    normalized.blank? || UNTITLED_TITLES.include?(normalized)
  end

  def can_auto_generate_title?
    !title_locked_by_user? && title_effectively_untitled?
  end

  def context_suggestions_enabled?
    return true unless has_attribute?(:context_suggestions_enabled)

    self[:context_suggestions_enabled] != false
  end
end
