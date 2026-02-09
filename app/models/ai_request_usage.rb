class AiRequestUsage < ApplicationRecord
  STATUSES = %w[running completed failed].freeze

  belongs_to :company
  belongs_to :chat, optional: true
  belongs_to :user_message, optional: true
  belongs_to :ai_message, optional: true

  validates :request_kind, presence: true
  validates :provider, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_blank: false

  after_create_commit :broadcast_admin_usage_created
  after_update_commit :broadcast_admin_usage_updated

  def running?
    status.to_s == "running"
  end

  def completed?
    status.to_s == "completed"
  end

  def failed?
    status.to_s == "failed"
  end

  private

  def broadcast_admin_usage_created
    broadcast_report_refresh

    Turbo::StreamsChannel.broadcast_remove_to(
      [:admin, :ai_usage],
      target: "admin_ai_usage_live_feed_empty"
    )

    Turbo::StreamsChannel.broadcast_prepend_to(
      [:admin, :ai_usage],
      target: "admin_ai_usage_live_feed_items",
      partial: "admin/ai_usage/live_request",
      locals: { usage: self }
    )
  rescue => e
    Rails.logger.info("[AiRequestUsage] broadcast create failed: #{e.class}: #{e.message}")
    nil
  end

  def broadcast_admin_usage_updated
    broadcast_report_refresh

    Turbo::StreamsChannel.broadcast_replace_to(
      [:admin, :ai_usage],
      target: ActionView::RecordIdentifier.dom_id(self, :live),
      partial: "admin/ai_usage/live_request",
      locals: { usage: self }
    )
  rescue => e
    Rails.logger.info("[AiRequestUsage] broadcast update failed: #{e.class}: #{e.message}")
    nil
  end

  def broadcast_report_refresh
    data = Ai::Usage::ReportData.new.call

    Turbo::StreamsChannel.broadcast_update_to(
      [:admin, :ai_usage],
      target: "admin_ai_usage_report",
      partial: "admin/ai_usage/report",
      locals: {
        totals: data[:totals],
        requests: data[:requests],
        kind_rows: data[:kind_rows],
        run_rows: data[:run_rows],
        chat_rows: data[:chat_rows]
      }
    )
  end
end
