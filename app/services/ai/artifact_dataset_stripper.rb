# app/services/ai/artifact_dataset_stripper.rb
#
# Removes the inert dataset JSON script block from artifact HTML.
#
# Why:
# - The dataset must be edited outside the iframe (Turbo Frames in the main DOM).
# - The artifact iframe is sandboxed and should remain purely presentational.
# - Prevents duplicate dataset rendering/interaction inside the iframe.
#
# Target:
#   <script type="application/json" id="artifact_dataset"> ... </script>
#
# Security posture:
# - Server-side parse only (Nokogiri), no execution.
# - Fail closed: if anything goes wrong, return the original HTML.

module Ai
  class ArtifactDatasetStripper
    def self.call(html)
      new(html).call
    end

    def initialize(html)
      @html = html.to_s
    end

    def call
      return @html if @html.blank?

      doc = Nokogiri::HTML(@html)
      node = doc.at_css('script#artifact_dataset[type="application/json"]')
      return @html unless node

      node.remove
      doc.to_html
    rescue => e
      Rails.logger.info("[Ai::ArtifactDatasetStripper] failed: #{e.class}: #{e.message}")
      @html
    end
  end
end
