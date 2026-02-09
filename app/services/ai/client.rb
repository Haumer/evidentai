module Ai
  class Client
    DEFAULT_PROVIDER = ENV.fetch("AI_PROVIDER", "openai").freeze

    def initialize(provider: DEFAULT_PROVIDER)
      @provider = provider.to_s
    end

    # Contract:
    # - prompt_snapshot may be:
    #   1) String
    #   2) Array of messages [{role:, content:}, ...]
    #
    # Returns a provider-agnostic result:
    # - { text: String, raw: Object|nil }
    def generate(prompt_snapshot:, model:, settings: {})
      raw_result = provider_client.generate(
        prompt_snapshot: prompt_snapshot,
        model: model,
        settings: settings
      )

      normalize_result(raw_result)
    end

    private

    def normalize_result(result)
      # Providers may return a plain string
      return { text: result.to_s, raw: nil } if result.is_a?(String)

      # Providers may return { content: { text: ... }, raw: ..., usage: ..., provider: ..., model: ... }
      if result.is_a?(Hash)
        text =
          result.dig(:text) ||
          result.dig("text") ||
          result.dig(:content, :text) ||
          result.dig("content", "text") ||
          result.dig(:content, "text") ||
          result.dig("content", :text)

        return {
          text: text.to_s,
          raw: result[:raw] || result["raw"],
          usage: result[:usage] || result["usage"],
          provider: result[:provider] || result["provider"],
          model: result[:model] || result["model"],
          provider_request_id: result[:provider_request_id] || result["provider_request_id"]
        }
      end

      # Fallback
      { text: result.to_s, raw: result }
    end

    def provider_client
      case @provider
      when "openai"
        Providers::OpenaiClient.new
      else
        raise ArgumentError, "Unknown AI provider: #{@provider.inspect}"
      end
    end
  end
end
