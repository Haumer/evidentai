module Ai
  module Links
    class Harden
      SAFE_SCHEMES = %w[http https mailto tel].freeze
      REQUIRED_REL_TOKENS = %w[noopener noreferrer].freeze

      def self.call(html, target_blank: true)
        new(html, target_blank: target_blank).call
      end

      def initialize(html, target_blank:)
        @html = html.to_s
        @target_blank = target_blank
      end

      def call
        return @html if @html.blank?

        if full_document?(@html)
          harden_document(@html)
        else
          harden_fragment(@html)
        end
      rescue => e
        Rails.logger.info("[Ai::Links::Harden] failed: #{e.class}: #{e.message}")
        @html
      end

      private

      def full_document?(html)
        html.match?(%r{<html[\s>]}i)
      end

      def harden_document(html)
        doc = Nokogiri::HTML(html)
        harden_anchor_nodes!(doc.css("a"))
        doc.to_html
      end

      def harden_fragment(html)
        fragment = Nokogiri::HTML::DocumentFragment.parse(html)
        harden_anchor_nodes!(fragment.css("a"))
        fragment.to_html
      end

      def harden_anchor_nodes!(nodes)
        nodes.each { |node| harden_anchor!(node) }
      end

      def harden_anchor!(node)
        href = node["href"].to_s.strip
        node.remove_attribute("href") if href.present? && unsafe_href?(href)

        return unless @target_blank

        node["target"] = "_blank"
        rel_tokens = node["rel"].to_s.split(/\s+/).map(&:downcase).reject(&:blank?)
        REQUIRED_REL_TOKENS.each do |token|
          rel_tokens << token unless rel_tokens.include?(token)
        end
        node["rel"] = rel_tokens.join(" ")
      end

      def unsafe_href?(href)
        return false if href.start_with?("#", "/", "./", "../", "?")

        scheme_match = href.match(/\A([a-zA-Z][a-zA-Z0-9+\-.]*):/)
        return false unless scheme_match

        scheme = scheme_match[1].to_s.downcase
        !SAFE_SCHEMES.include?(scheme)
      end
    end
  end
end
