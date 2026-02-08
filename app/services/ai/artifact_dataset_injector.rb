# app/services/ai/artifact_dataset_injector.rb
#
# Ensures an artifact HTML document contains the inert dataset JSON blob:
#   <script type="application/json" id="artifact_dataset"> ... </script>
#
# Used when:
# - Persisting an artifact with extracted dataset_json
# - Re-rendering the artifact after user edits (dataset_locked_by_user)
#
# Security posture:
# - Server-side only, Nokogiri manipulation
# - No script execution (iframe is sandboxed and disallows scripts)
# - Fail closed: on any error, returns original html

module Ai
  class ArtifactDatasetInjector
    def self.call(html:, dataset_json:)
      new(html: html, dataset_json: dataset_json).call
    end

    def initialize(html:, dataset_json:)
      @html = html.to_s
      @dataset_json = dataset_json
    end

    def call
      return @html if @html.blank?
      return @html if @dataset_json.blank?

      doc = Nokogiri::HTML(@html)

      # Remove any existing dataset node first (avoid duplicates)
      existing = doc.at_css('script#artifact_dataset[type="application/json"]')
      existing&.remove

      # Ensure we have a <body> to append to (Nokogiri usually creates one)
      body = doc.at("body") || doc.root
      return @html unless body

      node = Nokogiri::XML::Node.new("script", doc)
      node["type"] = "application/json"
      node["id"] = "artifact_dataset"
      node.content = JSON.pretty_generate(@dataset_json)

      body.add_child(node)

      doc.to_html
    rescue => e
      Rails.logger.info("[Ai::ArtifactDatasetInjector] failed: #{e.class}: #{e.message}")
      @html
    end
  end
end
