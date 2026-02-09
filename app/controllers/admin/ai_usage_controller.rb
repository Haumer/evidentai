module Admin
  class AiUsageController < ApplicationController
    before_action :ensure_membership!

    def index
      data = Ai::Usage::ReportData.new(company: @company).call
      @totals = data[:totals]
      @requests = data[:requests]
      @kind_rows = data[:kind_rows]
      @run_rows = data[:run_rows]
      @chat_rows = data[:chat_rows]
      @live_requests =
        AiRequestUsage.where(company_id: @company.id)
                      .includes(:chat, :user_message)
                      .order(requested_at: :desc)
                      .limit(120)
                      .to_a
    end

    def retry_run
      user_message = UserMessage.where(company_id: @company.id).find(params.require(:user_message_id))
      Ai::Chat::RetryUserMessage.call(user_message: user_message)

      redirect_to admin_ai_usage_path, notice: "Resent UserMessage ##{user_message.id}."
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_ai_usage_path, alert: "Run not found."
    rescue ActionController::ParameterMissing
      redirect_to admin_ai_usage_path, alert: "Missing user message id."
    rescue ArgumentError => e
      redirect_to admin_ai_usage_path, alert: e.message
    rescue => e
      redirect_to admin_ai_usage_path, alert: "Failed to resend run: #{e.class}."
    end

    private

    def ensure_membership!
      membership = current_user.memberships.first
      redirect_to setup_path and return unless membership

      @company = membership.company
    end
  end
end
