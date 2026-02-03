# app/services/ai/stream_submit_prompt.rb
module Ai
  class StreamSubmitPrompt
    DEFAULT_MODEL = ENV.fetch("OPENAI_MODEL", "gpt-5.2")

    def initialize(prompt:)
      @prompt = prompt
    end

    # Streams a response from OpenAI and yields incremental plain-text deltas:
    #   yield(delta: "...", accumulated: "...")  (optional)
    #
    # IMPORTANT:
    # - We instruct the model (via ActionCatalog) to output STRICT JSON only.
    # - We stream the raw JSON text, then parse it at the end to persist:
    #   { "text": "...", "proposed_actions": [...] }
    def call
      @prompt.update!(status: "running", error_message: nil)

      accumulated = +""
      model = DEFAULT_MODEL

      stream = openai_client.responses.stream(
        model: model,
        input: build_input_messages
      )

      stream.each do |event|
        type = event_type(event)

        case type
        when "response.output_text.delta"
          delta = event_delta(event)
          next if delta.empty?

          accumulated << delta

          # IMPORTANT: only yield these two keywords
          yield(delta: delta, accumulated: accumulated) if block_given?

        when "response.completed"
          persist_final!(raw_text: accumulated, provider: "openai", model: model)
          return accumulated

        when "response.error"
          raise(event_error_message(event) || "OpenAI streaming error")
        else
          # ignore other event types
        end
      end

      # If stream ends without completed, persist what we have.
      persist_final!(raw_text: accumulated, provider: "openai", model: model)
      accumulated
    rescue => e
      @prompt.update!(status: "failed", error_message: e.message)
      raise
    end

    private

    def openai_client
      @openai_client ||= OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    end

    # Build an instruction format that allows:
    # - strict JSON output
    # - proposed actions constrained by the catalog
    #
    # Responses API accepts "input" as a string or an array of message-like hashes.
    # We'll pass an array of { role, content }.
    def build_input_messages
      [
        { role: "system", content: Ai::ActionCatalog.system_prompt_block },
        { role: "user", content: @prompt.instruction.to_s }
      ]
    end

    # --- event helpers (object OR hash) ---

    def event_type(event)
      if event.respond_to?(:type)
        event.type.to_s
      elsif event.is_a?(Hash)
        event["type"].to_s
      else
        ""
      end
    end

    def event_delta(event)
      if event.respond_to?(:delta)
        event.delta.to_s
      elsif event.is_a?(Hash)
        event["delta"].to_s
      else
        ""
      end
    end

    def event_error_message(event)
      if event.respond_to?(:error) && event.error.respond_to?(:message)
        event.error.message.to_s
      elsif event.is_a?(Hash) && event["error"].is_a?(Hash)
        event["error"]["message"].to_s
      end
    end

    # Persist final output:
    # - Attempt to parse strict JSON: { content: { text }, proposed_actions: [...] }
    # - Validate + normalize proposed actions against ActionCatalog
    # - Persist to Output#content as:
    #     {
    #       "text" => "...",
    #       "proposed_actions" => [ { "type" => "...", "title" => "...", "payload" => {...} }, ... ],
    #       "raw" => { ... } # (optional)
    #     }
    def persist_final!(raw_text:, provider:, model:)
      parsed = parse_json(raw_text.to_s)

      text =
        if parsed.is_a?(Hash) && parsed["content"].is_a?(Hash) && parsed["content"]["text"].present?
          parsed["content"]["text"].to_s
        else
          # Fallback: treat the streamed content as plain text
          raw_text.to_s
        end

      proposed_actions =
        if parsed.is_a?(Hash) && parsed["proposed_actions"].is_a?(Array)
          normalize_actions(parsed["proposed_actions"])
        else
          []
        end

      payload = {
        "text" => text,
        "proposed_actions" => proposed_actions
      }

      # Keep the raw parsed JSON around for debugging/audit (optional, but helpful).
      payload["raw"] = parsed if parsed.is_a?(Hash)

      if @prompt.output.present?
        @prompt.output.update!(content: payload)
      else
        @prompt.create_output!(content: payload)
      end

      @prompt.update!(
        status: "done",
        llm_provider: provider,
        llm_model: model,
        frozen_at: (@prompt.frozen_at || Time.current)
      )
    end

    def parse_json(str)
      JSON.parse(str)
    rescue JSON::ParserError
      nil
    end

    # Takes an array of action hashes (untrusted), returns a cleaned array
    # that only contains allowed action types + allowed payload keys.
    def normalize_actions(actions)
      actions.filter_map do |a|
        next unless a.is_a?(Hash)

        type = (a["type"] || a[:type]).to_s
        next unless Ai::ActionCatalog.allowed_type?(type)

        title = (a["title"] || a[:title]).to_s
        payload = a["payload"] || a[:payload]
        payload = {} unless payload.is_a?(Hash)

        normalized_payload = Ai::ActionCatalog.normalize_payload(type, payload)

        # Validate required keys; if invalid, drop the action (MVP-safe behavior)
        begin
          Ai::ActionCatalog.validate!(type, normalized_payload)
        rescue ArgumentError
          next
        end

        {
          "type" => type,
          "title" => title.presence || Ai::ActionCatalog.fetch(type)&.title.to_s,
          "payload" => normalized_payload
        }
      end
    end
  end
end
