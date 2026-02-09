module Ai
  module Usage
    class Pricing
      DEFAULT_INPUT_RATE = ENV.fetch("AI_DEFAULT_INPUT_RATE_PER_1M_USD", "0").to_d
      DEFAULT_OUTPUT_RATE = ENV.fetch("AI_DEFAULT_OUTPUT_RATE_PER_1M_USD", "0").to_d

      def self.for_model(model)
        normalized = normalize_model(model)
        input = ENV.fetch("AI_PRICE_#{normalized}_INPUT_PER_1M_USD", DEFAULT_INPUT_RATE.to_s).to_d
        output = ENV.fetch("AI_PRICE_#{normalized}_OUTPUT_PER_1M_USD", DEFAULT_OUTPUT_RATE.to_s).to_d

        { input_rate_per_1m_usd: input, output_rate_per_1m_usd: output }
      end

      def self.normalize_model(model)
        model.to_s.upcase.gsub(/[^A-Z0-9]+/, "_").gsub(/\A_+|_+\z/, "").presence || "UNKNOWN"
      end
    end
  end
end
