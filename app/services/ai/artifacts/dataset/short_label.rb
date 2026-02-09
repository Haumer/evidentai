module Ai
  module Artifacts
    module Dataset
      class ShortLabel
        DEFAULT_MAX_CHARS = 48

        def self.call(name, fallback:, max_chars: DEFAULT_MAX_CHARS)
          raw = name.to_s
          text = raw.gsub(/\s+/, " ").strip
          text = text.sub(/\s*\([^)]*\)\s*\z/, "").strip
          text = fallback.to_s if text.blank?

          max = max_chars.to_i
          return text if max <= 0 || text.length <= max

          "#{text[0, max - 1].rstrip}..."
        rescue
          fallback.to_s
        end
      end
    end
  end
end
