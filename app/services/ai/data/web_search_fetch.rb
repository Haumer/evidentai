require "json"
require "openai"
require "uri"

module Ai
  module Data
    class WebSearchFetch
      DEFAULT_MODEL = ENV.fetch("OPENAI_MODEL", "gpt-5.2").freeze
      DEFAULT_TOOL_CANDIDATES = %w[web_search_preview web_search].freeze
      MAX_SOURCES = 20

      def initialize(model: DEFAULT_MODEL, client: nil, tool_candidates: DEFAULT_TOOL_CANDIDATES)
        @model = model.presence || DEFAULT_MODEL
        @client = client || OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
        @tool_candidates = Array(tool_candidates).map(&:to_s).reject(&:blank?)
        @tool_candidates = DEFAULT_TOOL_CANDIDATES if @tool_candidates.empty?
      end

      # Returns:
      # {
      #   ok: true/false,
      #   available_data: Hash|nil,
      #   sources_json: Array,
      #   raw_payload: Hash|nil,
      #   raw_text: String
      # }
      def call(query_text:, context_text: nil, preferred_sources: nil, user_message: nil, ai_message: nil, chat: nil)
        response = run_response_with_tool_fallback(
          query_text: query_text.to_s,
          context_text: context_text.to_s,
          preferred_sources: preferred_sources
        )
        track_usage!(response, user_message: user_message, ai_message: ai_message, chat: chat)

        raw_text = extract_output_text(response)
        parsed = parse_json_object(raw_text)
        normalized = normalize_payload(
          parsed,
          query_text: query_text.to_s,
          response: response
        )

        {
          ok: true,
          available_data: normalized[:available_data],
          sources_json: normalized[:sources_json],
          raw_payload: parsed,
          raw_text: raw_text
        }
      rescue => e
        {
          ok: false,
          error: e.message,
          available_data: nil,
          sources_json: [],
          raw_payload: nil,
          raw_text: defined?(raw_text) ? raw_text.to_s : ""
        }
      end

      private

      def run_response_with_tool_fallback(query_text:, context_text:, preferred_sources:)
        error = nil

        @tool_candidates.each do |tool_type|
          return @client.responses.create(
            model: @model,
            input: build_input_messages(
              query_text: query_text,
              context_text: context_text,
              preferred_sources: preferred_sources
            ),
            tools: [{ type: tool_type }]
          )
        rescue => e
          error = e
          next
        end

        raise(error || "No web search tool candidate succeeded")
      end

      def build_input_messages(query_text:, context_text:, preferred_sources:)
        source_hints = normalize_preferred_sources(preferred_sources)

        [
          {
            role: "system",
            content: <<~TEXT
              You are a web research assistant.
              Use the web search tool and return JSON only.
              Do not include markdown fences.
            TEXT
          },
          {
            role: "user",
            content: <<~TEXT
              Query: #{query_text}

              Context:
              #{context_text.presence || "(none)"}

              Preferred previous sources:
              #{source_hints.presence || "(none)"}

              Return exactly one JSON object with these keys:
              {
                "query_summary": string,
                "as_of_date": "YYYY-MM-DD" | null,
                "dataset": {
                  "version": 1,
                  "datasets": [
                    {
                      "name": string,
                      "units": string | null,
                      "schema": string[],
                      "rows": any[][]
                    }
                  ]
                } | null,
                "sources": [
                  {
                    "title": string,
                    "url": string,
                    "publisher": string | null,
                    "published_at": string | null,
                    "notes": string | null
                  }
                ],
                "notes": string | null
              }

              Source URL quality rules:
              - Use direct page URLs for the cited facts (deep links), not site homepages.
              - Only use a homepage URL when a specific page URL is truly unavailable.
            TEXT
          }
        ]
      end

      def normalize_preferred_sources(preferred_sources)
        Array(preferred_sources).first(10).map do |entry|
          next unless entry.is_a?(Hash)

          entry["url"] || entry[:url] || entry["href"] || entry[:href] || entry["title"] || entry[:title]
        end.compact.join(", ")
      end

      def extract_output_text(response)
        return response.output_text.to_s if response.respond_to?(:output_text)

        if response.respond_to?(:output)
          text = Array(response.output).filter_map do |item|
            if item.respond_to?(:content)
              Array(item.content).filter_map do |part|
                part.respond_to?(:text) ? part.text.to_s : nil
              end.join("\n")
            end
          end.join("\n").strip

          return text if text.present?
        end

        if response.is_a?(Hash)
          text = response["output_text"] || response.dig("output", 0, "content", 0, "text")
          return text.to_s if text.present?
        end

        raise "No text output returned from web search response"
      end

      def parse_json_object(text)
        str = text.to_s.strip

        return JSON.parse(str) if str.start_with?("{") && str.end_with?("}")

        if (match = str.match(/\{.*\}/m))
          return JSON.parse(match[0])
        end

        raise JSON::ParserError, "No JSON object found in web search response"
      end

      def normalize_payload(parsed, query_text:, response:)
        payload = parsed.is_a?(Hash) ? parsed : {}
        dataset = payload["dataset"]
        dataset = nil unless dataset.is_a?(Hash)
        sources = normalize_sources(payload["sources"], response: response)

        {
          available_data: {
            "query" => query_text.to_s,
            "query_summary" => payload["query_summary"].to_s.presence,
            "as_of_date" => payload["as_of_date"].presence,
            "dataset" => dataset,
            "sources" => sources,
            "notes" => payload["notes"].to_s.presence
          }.compact,
          sources_json: sources
        }
      end

      def normalize_sources(source_entries, response:)
        model_sources = normalize_source_entries(source_entries)
        citation_sources = extract_cited_sources(response)

        if model_sources.empty?
          return citation_sources.first(MAX_SOURCES)
        end

        citations_by_host = citation_sources.group_by { |entry| host_for(entry["url"]) }
        enriched = model_sources.map do |entry|
          enrich_source_with_citation(
            entry,
            citations_by_host: citations_by_host,
            citation_sources: citation_sources
          )
        end

        dedupe_sources(enriched).first(MAX_SOURCES)
      end

      def normalize_source_entries(source_entries)
        Array(source_entries).first(MAX_SOURCES).filter_map do |entry|
          next unless entry.is_a?(Hash)

          url = normalize_url(entry["url"])
          next if url.blank?

          {
            "title" => entry["title"].to_s.presence,
            "url" => url,
            "publisher" => entry["publisher"].presence,
            "published_at" => entry["published_at"].presence,
            "notes" => entry["notes"].presence
          }.compact
        end
      end

      def enrich_source_with_citation(entry, citations_by_host:, citation_sources:)
        current_url = entry["url"].to_s
        return entry if current_url.present? && deep_link?(current_url)

        replacement = choose_replacement_source(
          current_url: current_url,
          citations_by_host: citations_by_host,
          citation_sources: citation_sources
        )

        return entry if replacement.blank?

        entry.merge(
          "title" => entry["title"].presence || replacement["title"],
          "url" => replacement["url"],
          "publisher" => entry["publisher"].presence || replacement["publisher"]
        ).compact
      end

      def choose_replacement_source(current_url:, citations_by_host:, citation_sources:)
        host = host_for(current_url)
        same_host = host.present? ? Array(citations_by_host[host]) : []

        same_host.find { |entry| deep_link?(entry["url"]) } ||
          same_host.first ||
          citation_sources.find { |entry| deep_link?(entry["url"]) } ||
          citation_sources.first
      end

      def extract_cited_sources(response)
        payload = response_to_hash(response)
        return [] if payload.blank?

        candidates = []
        walk_nested(payload) do |node|
          next unless node.is_a?(Hash)

          source = citation_source_from_hash(node)
          candidates << source if source.present?
        end

        dedupe_sources(candidates).first(MAX_SOURCES)
      end

      def response_to_hash(response)
        return response if response.is_a?(Hash) || response.is_a?(Array)
        return response.to_h if response.respond_to?(:to_h)

        nil
      rescue
        nil
      end

      def walk_nested(node, &block)
        yield node

        case node
        when Hash
          node.each_value { |value| walk_nested(value, &block) }
        when Array
          node.each { |value| walk_nested(value, &block) }
        end
      end

      def citation_source_from_hash(node)
        url = normalize_url(node["url"] || node[:url] || node["source_url"] || node[:source_url])
        return nil if url.blank?

        type = (node["type"] || node[:type]).to_s.downcase
        has_citation_signal = type.include?("citation") || type.include?("result") || type.include?("source")

        has_metadata_signal = %w[
          title
          publisher
          published_at
          publishedAt
          site_name
          source
          snippet
        ].any? { |key| node.key?(key) || node.key?(key.to_sym) }

        return nil unless has_citation_signal || has_metadata_signal

        {
          "title" => (node["title"] || node[:title]).to_s.presence,
          "url" => url,
          "publisher" => (node["publisher"] || node[:publisher] || node["site_name"] || node[:site_name]).to_s.presence,
          "published_at" => (node["published_at"] || node[:published_at] || node["publishedAt"] || node[:publishedAt]).to_s.presence
        }.compact
      end

      def dedupe_sources(entries)
        seen = {}
        entries.filter_map do |entry|
          next unless entry.is_a?(Hash)

          url = normalize_url(entry["url"])
          next if url.blank?
          next if seen[url]

          seen[url] = true
          entry.merge("url" => url)
        end
      end

      def deep_link?(url)
        uri = parse_uri(url)
        return false if uri.blank? || uri.host.blank?

        path = uri.path.to_s
        path.present? && path != "/" || uri.query.present? || uri.fragment.present?
      end

      def host_for(url)
        parse_uri(url)&.host.to_s.downcase.presence
      end

      def normalize_url(url)
        str = url.to_s.strip
        return nil if str.blank?

        uri = parse_uri(str)
        return nil if uri.blank? || uri.scheme.blank? || uri.host.blank?

        uri.to_s
      end

      def parse_uri(url)
        URI.parse(url.to_s)
      rescue URI::InvalidURIError
        nil
      end

      def track_usage!(response, user_message:, ai_message:, chat:)
        Ai::Usage::TrackRequest.call(
          request_kind: "web_search_fetch",
          provider: "openai",
          model: @model,
          raw: response,
          user_message: user_message,
          ai_message: ai_message,
          chat: chat
        )
      rescue
        nil
      end
    end
  end
end
