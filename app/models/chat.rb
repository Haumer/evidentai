# app/models/chat.rb
class Chat < ApplicationRecord
  UNTITLED_TITLES = ["untitled", "untitled chat"].freeze

  before_validation :ensure_inbound_email_token

  belongs_to :company
  belongs_to :created_by, class_name: "User"

  has_many :user_messages, dependent: :destroy
  has_many :artifacts, dependent: :destroy
  has_many :artifact_triggers, dependent: :destroy
  has_many :data_source_caches, class_name: "DataSourceCache", dependent: :destroy
  has_many :ai_request_usages

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

  def untouched_for_new_chat?
    return false if title_set_by_user?
    return false unless title_effectively_untitled?
    return false if user_messages.exists?
    return false if artifacts.exists?

    true
  end

  def context_suggestions_enabled?
    return true unless has_attribute?(:context_suggestions_enabled)

    self[:context_suggestions_enabled] != false
  end

  def inbound_email_id
    return nil unless has_attribute?(:inbound_email_token)

    inbound_email_token.to_s.presence
  end

  def inbound_email_address
    token = inbound_email_id
    return nil if token.blank?

    domain = ENV.fetch("CHAT_INBOUND_EMAIL_DOMAIN", "").to_s.strip
    return token if domain.blank?

    "#{token}@#{domain}"
  end

  private

  def ensure_inbound_email_token
    return unless has_attribute?(:inbound_email_token)
    return if inbound_email_token.present?

    self.inbound_email_token = build_unique_inbound_email_token
  end

  def build_unique_inbound_email_token
    loop do
      token = SecureRandom.urlsafe_base64(18)
      return token unless self.class.where(inbound_email_token: token).exists?
    end
  end
end
