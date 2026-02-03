# frozen_string_literal: true

module Ai
  module Config
    PROVIDERS = {
      "openai" => {
        api_key_env: "OPENAI_API_KEY",
        default_model: "gpt-4.1"
      }
      # Later:
      # "anthropic" => { api_key_env: "ANTHROPIC_API_KEY", default_model: "claude-3-..." }
      # "azure_openai" => { api_key_env: "AZURE_OPENAI_KEY", default_model: "gpt-4o-mini" }
    }.freeze

    def self.for!(provider)
      PROVIDERS.fetch(provider.to_s) do
        raise ArgumentError, "Unknown AI provider: #{provider.inspect}"
      end
    end

    def self.api_key_for!(provider)
      env = for!(provider)[:api_key_env]
      key = ENV[env]
      raise "Missing ENV #{env} for provider=#{provider}" if key.nil? || key.strip.empty?
      key
    end

    def self.default_model_for(provider)
      for!(provider)[:default_model]
    end
  end
end
