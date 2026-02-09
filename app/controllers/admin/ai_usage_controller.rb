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
                      .reverse
    end

    private

    def ensure_membership!
      membership = current_user.memberships.first
      redirect_to setup_path and return unless membership

      @company = membership.company
    end
  end
end
