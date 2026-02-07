# app/models/proposed_action.rb
class ProposedAction < ApplicationRecord
  STATUSES = %w[proposed approved dismissed].freeze

  belongs_to :ai_message

  belongs_to :approved_by,  class_name: "User", optional: true
  belongs_to :dismissed_by, class_name: "User", optional: true

  validates :action_type, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  validate :payload_must_be_hash
  validate :metadata_must_be_hash

  scope :proposed,  -> { where(status: "proposed") }
  scope :approved,  -> { where(status: "approved") }
  scope :dismissed, -> { where(status: "dismissed") }

  def proposed?
    status == "proposed"
  end

  def approved?
    status == "approved"
  end

  def dismissed?
    status == "dismissed"
  end

  private

  def payload_must_be_hash
    errors.add(:payload, "must be a JSON object") unless payload.is_a?(Hash)
  end

  def metadata_must_be_hash
    errors.add(:metadata, "must be a JSON object") unless metadata.is_a?(Hash)
  end
end
