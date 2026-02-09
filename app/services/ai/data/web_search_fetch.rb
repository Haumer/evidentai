require "json"
require "openai"

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
      def call(query_text:, context_text: nil, preferred_sources: nil)
        response = run_response_with_tool_fallback(
          query_text: query_text.to_s,
          context_text: context_text.to_s,
          preferred_sources: preferred_sources
        )

        raw_text = extract_output_text(response)
        parsed = parse_json_object(raw_text)
        normalized = normalize_payload(parsed, query_text: query_text.to_s)

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

      def normalize_payload(parsed, query_text:)
        payload = parsed.is_a?(Hash) ? parsed : {}
        dataset = payload["dataset"]
        dataset = nil unless dataset.is_a?(Hash)

        sources = Array(payload["sources"]).first(MAX_SOURCES).map do |entry|
          next unless entry.is_a?(Hash)

          {
            "title" => entry["title"].to_s,
            "url" => entry["url"].to_s,
            "publisher" => entry["publisher"].presence,
            "published_at" => entry["published_at"].presence,
            "notes" => entry["notes"].presence
          }.compact
        end.compact

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
    end
  end
end
