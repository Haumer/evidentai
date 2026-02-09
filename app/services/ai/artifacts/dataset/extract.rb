# app/services/ai/artifacts/dataset/extract.rb
#
# Extracts an inert dataset JSON blob (and best-effort sources) from an HTML document.
# The dataset is expected in:
#   <script type="application/json" id="artifact_dataset"> ... </script>
#
# Security posture:
# - No execution (server-side parse only).
# - Fail closed: invalid JSON or schema => returns nil dataset.
# - Size guardrails prevent huge payloads.
#
module Ai
  module Artifacts
    module Dataset
      class Extract
        MAX_JSON_BYTES = 150_000 # ~150KB, plenty for small charts/tables
        MAX_SOURCES_ITEMS = 50
        MAX_SOURCE_TEXT_CHARS = 500
        MAX_HREF_CHARS = 2_000

        def self.call(html)
          new(html).call
        end

        def initialize(html)
          @html = html.to_s
        end

        def call
          dataset_json = extract_dataset_json
          sources_json = extract_sources_json

          { dataset_json: dataset_json, sources_json: sources_json }
        rescue => e
          Rails.logger.info("[Ai::Artifacts::Dataset::Extract] failed: #{e.class}: #{e.message}")
          { dataset_json: nil, sources_json: nil }
        end

        private

        def extract_dataset_json
          return nil if @html.blank?

          doc = Nokogiri::HTML(@html)
          node = doc.at_css('script#artifact_dataset[type="application/json"]')
          return nil unless node

          raw = node.text.to_s.strip
          return nil if raw.blank?
          return nil if raw.bytesize > MAX_JSON_BYTES

          parsed = JSON.parse(raw)
          return nil unless valid_dataset_object?(parsed)

          parsed
        rescue JSON::ParserError
          nil
        end

        # Best-effort: read a "Sources" section and normalize into structured data.
        # This is intentionally forgiving and may return nil if not found.
        def extract_sources_json
          return nil if @html.blank?

          doc = Nokogiri::HTML(@html)

          heading = doc.css("h1,h2,h3,h4").find { |h| h.text.to_s.strip.casecmp("sources").zero? }
          return nil unless heading

          list = heading.xpath("following-sibling::*").find { |n| n.name == "ul" }
          return nil unless list

          items = list.css("li").first(MAX_SOURCES_ITEMS).map do |li|
            text = li.text.to_s.strip
            next if text.blank?

            text = text[0, MAX_SOURCE_TEXT_CHARS]

            a = li.at_css("a")
            href = a&.[]("href").to_s.strip
            href = nil if href.blank?
            href = href[0, MAX_HREF_CHARS] if href

            # Avoid storing obviously unsafe schemes; we never execute, but keep data clean.
            if href
              scheme = href.split(":", 2).first.to_s.downcase
              href = nil if %w[javascript data vbscript].include?(scheme)
            end

            href ? { text: text, href: href } : { text: text }
          end

          items.compact.presence
        rescue
          nil
        end

        def valid_dataset_object?(obj)
          return false unless obj.is_a?(Hash)

          version = obj["version"] || obj[:version]
          return false unless version.is_a?(Integer)

          datasets = obj["datasets"] || obj[:datasets]
          return false unless datasets.is_a?(Array)
          return false if datasets.empty?

          datasets.all? { |ds| valid_dataset_entry?(ds) }
        end

        def valid_dataset_entry?(ds)
          return false unless ds.is_a?(Hash)

          schema = ds["schema"] || ds[:schema]
          rows = ds["rows"] || ds[:rows]

          return false unless schema.is_a?(Array) && schema.all? { |c| c.is_a?(String) }
          return false unless rows.is_a?(Array) && rows.all? { |r| r.is_a?(Array) }

          true
        end
      end
    end
  end
end
