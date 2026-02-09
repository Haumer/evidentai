# app/services/ai/artifacts/inject_base_styles.rb
#
# Ensures generated artifact documents have baseline, consistent link styling.

module Ai
  module Artifacts
    class InjectBaseStyles
      STYLE_ID = "artifact_base_styles".freeze

      def self.call(html:)
        new(html: html).call
      end

      def initialize(html:)
        @html = html.to_s
      end

      def call
        return @html if @html.blank?

        doc = Nokogiri::HTML(@html)

        head = doc.at("head")
        unless head
          html = doc.at("html") || doc.root
          return @html unless html

          head = Nokogiri::XML::Node.new("head", doc)
          html.children.first ? html.children.first.add_previous_sibling(head) : html.add_child(head)
        end

        existing = doc.at_css("style##{STYLE_ID}")
        existing&.remove

        node = Nokogiri::XML::Node.new("style", doc)
        node["id"] = STYLE_ID
        node.content = <<~CSS
          a{
            color:#0b63ce;
            text-decoration:underline;
            text-decoration-thickness:1.5px;
            text-underline-offset:2px;
          }
          a:hover{
            color:#084fa4;
          }
          a:focus-visible{
            outline:2px solid rgba(11,99,206,0.35);
            outline-offset:2px;
            border-radius:2px;
          }
        CSS

        head.add_child(node)
        doc.to_html
      rescue => e
        Rails.logger.info("[Ai::Artifacts::InjectBaseStyles] failed: #{e.class}: #{e.message}")
        @html
      end
    end
  end
end
