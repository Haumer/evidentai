# app/services/ai/artifacts/dataset/apply_to_html.rb
#
# Applies deterministic, server-side dataset-related rendering to artifact HTML.
# This keeps iframe output synchronized after dataset edits without JS.

module Ai
  module Artifacts
    module Dataset
      class ApplyToHtml
        def self.call(html:, dataset_json:)
          new(html: html, dataset_json: dataset_json).call
        end

        def initialize(html:, dataset_json:)
          @html = html.to_s
          @dataset_json = dataset_json
        end

        def call
          html = Ai::Artifacts::InjectBaseStyles.call(html: @html)
          return html if @dataset_json.blank?

          html = Ai::Artifacts::Dataset::Inject.call(html: html, dataset_json: @dataset_json)
          html = Ai::Artifacts::Dataset::InjectVisuals.call(html: html, dataset_json: @dataset_json)
          Ai::Artifacts::Dataset::InjectTables.call(html: html, dataset_json: @dataset_json)
        rescue => e
          Rails.logger.info("[Ai::Artifacts::Dataset::ApplyToHtml] failed: #{e.class}: #{e.message}")
          @html
        end
      end
    end
  end
end
