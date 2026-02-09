module Ai
  module Data
    class ResolveAvailableData
      REFRESH_SEARCH_PATTERN = /
        (
          \b(refresh|re-run|rerun|re-fetch|refetch|search\ again|fetch\ again)\b
          .*?
          \b(data|sources?|search|web)\b
        )|
        (\brefresh\s+from\s+source\b)
      /ix.freeze

      SOURCE_NEEDS_HEURISTIC = /
        \b(
          source|sources|citation|citations|latest|today|current|news|price|prices|
          gdp|inflation|market|exchange\ rate|schedule|regulation|law|over\s+\d+\s+years?
        )\b
      /ix.freeze

      def initialize(context:, fetcher: nil)
        @context = context
        @user_message = context.user_message
        @chat = context.chat
        @fetcher = fetcher
      end

      # Returns:
      # {
      #   needed: true/false,
      #   decision: "not_needed"|"use_cache"|"search"|"search_failed",
      #   forced_refresh: true/false,
      #   query_signature: String,
      #   available_data: Hash|nil,
      #   error: String|nil
      # }
      def call
        key = SourceCacheKey.call(@user_message.instruction)

        return not_needed_result(key) unless needs_sources?

        forced_refresh = force_refresh_requested?
        cache = find_cache(key[:query_signature])

        if cache.present? && !forced_refresh
          return cache_result(key, cache, decision: "use_cache", forced_refresh: false)
        end

        fetched = fetcher.call(
          query_text: @user_message.instruction.to_s,
          context_text: @context.context_text.to_s,
          preferred_sources: cache&.sources_json,
          user_message: @user_message,
          ai_message: @context.ai_message,
          chat: @chat
        )

        if fetched[:ok]
          saved_cache = upsert_cache!(key: key, fetched: fetched)
          return cache_result(key, saved_cache, decision: "search", forced_refresh: forced_refresh)
        end

        return cache_result(key, cache, decision: "use_cache", forced_refresh: forced_refresh, error: fetched[:error]) if cache.present?

        {
          needed: true,
          decision: "search_failed",
          forced_refresh: forced_refresh,
          query_signature: key[:query_signature],
          available_data: nil,
          error: fetched[:error].to_s
        }
      end

      private

      def fetcher
        @fetcher ||= Ai::Data::WebSearchFetch.new(model: @context.model)
      end

      def find_cache(query_signature)
        DataSourceCache.find_by(chat_id: @chat.id, query_signature: query_signature)
      end

      def upsert_cache!(key:, fetched:)
        cache = DataSourceCache.find_or_initialize_by(chat_id: @chat.id, query_signature: key[:query_signature])
        cache.company_id = @chat.company_id
        cache.query_text = key[:query_text].presence || @user_message.instruction.to_s
        cache.data_json = fetched[:available_data].is_a?(Hash) ? fetched[:available_data] : {}
        cache.sources_json = fetched[:sources_json].is_a?(Array) ? fetched[:sources_json] : []
        cache.last_fetched_at = Time.current
        cache.save!
        cache
      end

      def cache_result(key, cache, decision:, forced_refresh:, error: nil)
        available_data = cache.data_json.is_a?(Hash) ? cache.data_json.deep_dup : {}
        available_data["sources"] = cache.sources_json if cache.sources_json.is_a?(Array) && available_data["sources"].blank?
        available_data["query"] ||= cache.query_text.to_s

        {
          needed: true,
          decision: decision,
          forced_refresh: forced_refresh,
          query_signature: key[:query_signature],
          available_data: available_data.presence,
          error: error
        }
      end

      def not_needed_result(key)
        {
          needed: false,
          decision: "not_needed",
          forced_refresh: false,
          query_signature: key[:query_signature],
          available_data: nil,
          error: nil
        }
      end

      def needs_sources?
        meta = @context.meta.is_a?(Hash) ? @context.meta : {}

        needs_sources =
          truthy?(meta[:needs_sources]) ||
          truthy?(meta["needs_sources"]) ||
          truthy?(meta[:suggest_web_search]) ||
          truthy?(meta["suggest_web_search"])

        needs_sources || SOURCE_NEEDS_HEURISTIC.match?(@user_message.instruction.to_s)
      end

      def force_refresh_requested?
        settings_hash = @user_message.settings.is_a?(Hash) ? @user_message.settings : {}
        return true if settings_hash["force_web_search"] == true

        REFRESH_SEARCH_PATTERN.match?(@user_message.instruction.to_s)
      end

      def truthy?(value)
        value == true
      end
    end
  end
end
