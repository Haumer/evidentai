# frozen_string_literal: true
require "openai"

module Ai
  module Providers
    class OpenaiClient
      def initialize
        @client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
      end

      def generate(prompt_snapshot:, model:, settings: {})
        chat = @client.chat.completions.create(
          model: (model || "gpt-5.2"),
          messages: [
            { role: "system", content: "You are a careful assistant that produces structured, safe outputs." },
            { role: "user", content: prompt_snapshot }
          ],
          temperature: settings.fetch("temperature", 0.2)
        )

        text = chat.choices.first.message.content

        { content: { text: text }, raw: chat }
      end
    end
  end
end
