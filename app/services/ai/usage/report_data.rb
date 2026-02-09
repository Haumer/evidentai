module Ai
  module Usage
    class ReportData
      def initialize(company:, request_limit: 500, run_limit: 200)
        @company = company
        @request_limit = request_limit.to_i
        @run_limit = run_limit.to_i
      end

      def call
        base = ::AiRequestUsage.where(company_id: @company.id)

        {
          totals: aggregate(base),
          requests: base.includes(:chat, :user_message, :ai_message).order(requested_at: :desc).limit(@request_limit),
          kind_rows: build_kind_rows(base),
          run_rows: build_run_rows(base),
          chat_rows: build_chat_rows(base)
        }
      end

      private

      def build_kind_rows(base)
        rows = base.group(:request_kind)
                   .select(group_aggregate_select_sql(with_request_kind: true, with_user_message: false, with_chat: false))
                   .order(Arel.sql("COUNT(*) DESC, MAX(requested_at) DESC"))

        rows.map do |row|
          aggregate_hash(row).merge(
            request_kind: row.request_kind.to_s,
            request_kind_name: human_request_kind(row.request_kind),
            last_requested_at: row.try(:last_requested_at)
          )
        end
      end

      def aggregate(relation)
        row = relation.select(aggregate_select_sql).take
        aggregate_hash(row)
      end

      def build_run_rows(base)
        rows = base.where.not(user_message_id: nil)
                   .group(:chat_id, :user_message_id)
                   .select(group_aggregate_select_sql)
                   .order(Arel.sql("MAX(requested_at) DESC"))
                   .limit(@run_limit)

        user_messages = ::UserMessage.includes(:ai_message).where(id: rows.map(&:user_message_id)).index_by(&:id)
        chats = ::Chat.where(id: rows.map(&:chat_id)).index_by(&:id)

        rows.map do |row|
          user_message = user_messages[row.user_message_id]
          chat = chats[row.chat_id]

          aggregate_hash(row).merge(
            chat: chat,
            user_message: user_message,
            ai_message: user_message&.ai_message,
            output_updated: user_message&.artifact_updated? == true,
            last_requested_at: row.try(:last_requested_at)
          )
        end
      end

      def build_chat_rows(base)
        rows = base.group(:chat_id)
                   .select(group_aggregate_select_sql(with_user_message: false, with_chat: true))
                   .order(Arel.sql("SUM(total_cost_usd) DESC"))

        chats = ::Chat.where(id: rows.map(&:chat_id)).index_by(&:id)
        rows.map do |row|
          aggregate_hash(row).merge(
            chat_id: row.chat_id,
            chat: chats[row.chat_id],
            last_requested_at: row.try(:last_requested_at)
          )
        end
      end

      def aggregate_select_sql
        <<~SQL.squish
          COUNT(*) AS requests_count,
          COALESCE(SUM(input_tokens), 0) AS input_tokens,
          COALESCE(SUM(output_tokens), 0) AS output_tokens,
          COALESCE(SUM(total_tokens), 0) AS total_tokens,
          COALESCE(SUM(total_cost_usd), 0) AS total_cost_usd
        SQL
      end

      def group_aggregate_select_sql(with_request_kind: false, with_user_message: true, with_chat: true)
        prefix = []
        prefix << "request_kind" if with_request_kind
        prefix << "chat_id" if with_chat
        prefix << "user_message_id" if with_user_message
        prefix_sql = prefix.any? ? "#{prefix.join(', ')}," : ""

        <<~SQL.squish
          #{prefix_sql}
          COUNT(*) AS requests_count,
          COALESCE(SUM(input_tokens), 0) AS input_tokens,
          COALESCE(SUM(output_tokens), 0) AS output_tokens,
          COALESCE(SUM(total_tokens), 0) AS total_tokens,
          COALESCE(SUM(total_cost_usd), 0) AS total_cost_usd,
          MAX(requested_at) AS last_requested_at
        SQL
      end

      def aggregate_hash(row)
        {
          requests_count: row.try(:requests_count).to_i,
          input_tokens: row.try(:input_tokens).to_i,
          output_tokens: row.try(:output_tokens).to_i,
          total_tokens: row.try(:total_tokens).to_i,
          total_cost_usd: row.try(:total_cost_usd).to_d
        }
      end

      def human_request_kind(kind)
        kind.to_s.tr("_", " ").squeeze(" ").strip.titleize.presence || "Unknown"
      end
    end
  end
end
