class AiRequestUsage < ApplicationRecord
  belongs_to :company
  belongs_to :chat
  belongs_to :user_message, optional: true
  belongs_to :ai_message, optional: true

  validates :request_kind, presence: true
  validates :provider, presence: true

  after_create_commit :broadcast_admin_usage_refresh

  private

  def broadcast_admin_usage_refresh
    data = Ai::Usage::ReportData.new(company: company).call

    Turbo::StreamsChannel.broadcast_replace_to(
      [company, :ai_usage],
      target: "admin_ai_usage_report",
      partial: "admin/ai_usage/report",
      locals: {
        company: company,
        totals: data[:totals],
        requests: data[:requests],
        run_rows: data[:run_rows],
        chat_rows: data[:chat_rows]
      }
    )
  rescue => e
    Rails.logger.info("[AiRequestUsage] broadcast refresh failed: #{e.class}: #{e.message}")
    nil
  end
end
