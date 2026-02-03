module Ai
  class Client
    def initialize(provider:)
      @provider = provider.to_s
    end

    def generate(prompt_snapshot:, model:, settings: {})
      provider_client.generate(
        prompt_snapshot: prompt_snapshot,
        model: model,
        settings: settings
      )
    end

    private

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
