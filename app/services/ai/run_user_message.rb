# app/services/ai/run_user_message.rb
#
# Orchestrator for processing a single UserMessage.
#
# Responsibilities:
# 1) Stream assistant chat reply (left pane)
# 2) Update artifact/output (right pane)
# 3) Extract proposed actions (under assistant)
#
# Boundaries:
# - Prompt text lives in Ai::Prompts::* and composers
# - Streaming transport lives in Ai::Chat::StreamReply
# - Persistence lives in Ai::Chat::PersistReply (chat)
# - ALL Turbo broadcasting lives in Ai::Chat::Broadcast
# - Vendor abstraction lives in Ai::Client
#
# IMPORTANT:
# - Artifact persistence + broadcasting must only ever receive STRING text.
#   Provider raw payloads must never reach UI/persistence.

module Ai
  class RunUserMessage
    DEFAULT_MODEL = ENV.fetch("OPENAI_MODEL", "gpt-5.2").freeze
    DEFAULT_PROVIDER = ENV.fetch("AI_PROVIDER", "openai").freeze
    BROADCAST_EVERY_N_CHARS = 10

    # Ensures the "Updating output…" indicator is perceptible.
    MIN_OUTPUT_WORKING_MS = 350

    def initialize(user_message:, context: nil)
      @user_message = user_message
      @chat = user_message.chat
      @context = context.to_s.strip
    end

    def call
      ai_message = update_chat!
      update_artifact!(ai_message)
      extract_actions!
    end

    private

    # ------------------------------------------------------------
    # Chat pipeline (streamed, left pane)
    # ------------------------------------------------------------

    def update_chat!
      persist = Ai::Chat::PersistReply.new(user_message: @user_message)
      broadcaster = Ai::Chat::Broadcast::ReplyBroadcaster.new(user_message: @user_message)

      persist.mark_running!
      ai_message = persist.ensure_ai_message!

      messages = Ai::Chat::ComposeMessages.new(
        user_message: @user_message,
        context: context_text
      ).call

      accumulated = +""
      last_broadcast_len = 0

      broadcaster.start(accumulated: accumulated)

      streamer = Ai::Chat::StreamReply.new(messages: messages, model: DEFAULT_MODEL)

      final_text = streamer.call do |delta|
        accumulated << delta.to_s
        persist.append_delta!(ai_message: ai_message, delta: delta)

        if (accumulated.length - last_broadcast_len) >= BROADCAST_EVERY_N_CHARS
          broadcaster.stream(accumulated: accumulated)
          last_broadcast_len = accumulated.length
        end
      end

      persist.finalize!(ai_message: ai_message, text: final_text, model: DEFAULT_MODEL)
      broadcaster.final

      ai_message
    rescue => e
      persist&.mark_failed!(e) rescue nil
      Ai::Chat::Broadcast::ReplyBroadcaster.new(user_message: @user_message)
        .stream(accumulated: "⚠️ #{e.message}") rescue nil
      raise
    end

    def context_text
      return @context if @context.present?

      Ai::Context::BuildContext.new(
        chat: @chat,
        exclude_user_message_id: @user_message.id
      ).call
    end

    # ------------------------------------------------------------
    # Output pipeline (right pane, non-streamed for now)
    # ------------------------------------------------------------

    def update_artifact!(ai_message)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Show "Updating output…" inside the chat (under this assistant message).
      run_status_broadcaster.working

      # UX: immediately indicate the artifact is being regenerated.
      # Keep showing the previous output while working.
      previous_text = current_artifact_text.to_s
      artifact_broadcaster.replace(text: previous_text, status: "working")

      # Generate the new artifact output (STRING only)
      generated_text = generate_artifact_text

      # Parse dataset (if present) from the artifact HTML (data-only, inert in iframe).
      extracted = Ai::ArtifactDatasetExtractor.call(generated_text)

      # Store preview on the ai_message (best-effort)
      ai_message.update!(
        content: (ai_message.content || {}).merge("preview" => generated_text)
      ) rescue nil

      # Persist FIRST (so an Artifact record exists for editing), and compute the final text
      # that should be displayed (dataset-injected, lock-aware).
      final_text = persist_artifact_and_prepare_text!(
        generated_text,
        dataset_json: extracted[:dataset_json],
        sources_json: extracted[:sources_json]
      )

      # UX: broadcast final output ASAP (as a whole, non-streamed)
      artifact_broadcaster.replace(text: final_text.to_s, status: "ready")

      # Ensure the "working" indicator is visible for a beat (calm UX).
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000.0).round
      remaining_ms = MIN_OUTPUT_WORKING_MS - elapsed_ms
      sleep(remaining_ms / 1000.0) if remaining_ms.positive?

      # Mark ready in chat now that artifact is rendered.
      run_status_broadcaster.ready
    rescue => e
      artifact_broadcaster.replace(
        text: "⚠️ Failed to generate output: #{e.message}",
        status: "ready"
      )

      run_status_broadcaster.ready rescue nil
    end

    def generate_artifact_text
      result = client.generate(
        prompt_snapshot: Ai::UpdateArtifact.messages(
          @user_message,
          current_artifact_text: current_artifact_text
        ),
        model: DEFAULT_MODEL
      )

      result.fetch(:text).to_s
    end

    def current_artifact_text
      artifact = Artifact.where(chat_id: @chat.id).order(created_at: :desc).first
      return "" unless artifact

      if artifact.respond_to?(:content) && artifact.content.present?
        artifact.content.is_a?(Hash) ? artifact.content["text"].to_s : artifact.content.to_s
      elsif artifact.respond_to?(:data) && artifact.data.present?
        artifact.data.is_a?(Hash) ? artifact.data["text"].to_s : artifact.data.to_s
      elsif artifact.respond_to?(:body) && artifact.body.present?
        artifact.body.to_s
      elsif artifact.respond_to?(:text) && artifact.text.present?
        artifact.text.to_s
      else
        ""
      end
    end

    # Persists the artifact and returns the FINAL html/text that should be displayed.
    #
    # Rules:
    # - If dataset_locked_by_user = true, never overwrite dataset_json from extracted AI output.
    # - Always inject the "current" dataset_json (locked or newly-extracted) into the stored HTML
    #   so the iframe reflects the DB dataset.
    #
    # IMPORTANT:
    # - Schema requires artifacts.company_id, artifacts.created_by_id, artifacts.chat_id (NOT NULL).
    #   Set *_id fields explicitly to avoid silent failures.
    def persist_artifact_and_prepare_text!(generated_text, dataset_json: nil, sources_json: nil)
      artifact = Artifact.find_or_initialize_by(chat_id: @chat.id)

      # Satisfy NOT NULL constraints reliably.
      if Artifact.column_names.include?("company_id") && artifact.company_id.blank?
        artifact.company_id = @user_message.company_id
      end

      if Artifact.column_names.include?("created_by_id") && artifact.created_by_id.blank?
        artifact.created_by_id = @user_message.created_by_id
      end

      final_text = generated_text.to_s

      artifact.with_lock do
        artifact.assign_attributes(artifact_content_attributes(final_text))

        has_dataset_cols = Artifact.column_names.include?("dataset_json") &&
          Artifact.column_names.include?("dataset_locked_by_user")

        if has_dataset_cols
          unless artifact.dataset_locked_by_user?
            artifact.dataset_json = dataset_json
            artifact.sources_json = sources_json if Artifact.column_names.include?("sources_json")
          end
        elsif Artifact.column_names.include?("dataset_json")
          artifact.dataset_json = dataset_json
          artifact.sources_json = sources_json if Artifact.column_names.include?("sources_json")
        end

        # Ensure displayed/stored HTML reflects whatever dataset_json is currently authoritative.
        if Artifact.column_names.include?("dataset_json") && artifact.dataset_json.present?
          injected = Ai::ArtifactDatasetInjector.new(
            html: final_text,
            dataset_json: artifact.dataset_json
          ).call

          final_text = injected.to_s
          artifact.assign_attributes(artifact_content_attributes(final_text))
        end

        artifact.save!
      end

      final_text
    rescue => e
      # Make failures debuggable (validation + NOT NULL issues were being swallowed).
      if defined?(artifact) && artifact.respond_to?(:errors) && artifact.errors.any?
        Rails.logger.warn(
          "[Ai::RunUserMessage] Artifact persist failed: #{e.class}: #{e.message} — #{artifact.errors.full_messages.join(", ")}"
        )
      else
        Rails.logger.warn("[Ai::RunUserMessage] Artifact persist failed: #{e.class}: #{e.message}")
      end

      generated_text.to_s
    end

    def artifact_content_attributes(text)
      %w[content data body text].each do |col|
        next unless Artifact.column_names.include?(col)

        type = Artifact.columns_hash[col]&.type
        return({ col => { "text" => text.to_s } }) if %i[json jsonb].include?(type)
        return({ col => text.to_s })
      end

      raise "Artifact has no supported content field (expected one of: content/data/body/text)."
    end

    def artifact_broadcaster
      @artifact_broadcaster ||= Ai::Chat::Broadcast::ArtifactBroadcaster.new(chat: @chat)
    end

    def run_status_broadcaster
      @run_status_broadcaster ||= Ai::Chat::Broadcast::RunStatusBroadcaster.new(
        chat: @chat,
        user_message: @user_message
      )
    end

    # ------------------------------------------------------------
    # Actions (third AI call)
    # ------------------------------------------------------------

    def extract_actions!
      Ai::ExtractProposedActions.new(user_message: @user_message, context: context_text).call!
    end

    # ------------------------------------------------------------
    # AI client
    # ------------------------------------------------------------

    def client
      @client ||= Ai::Client.new(provider: DEFAULT_PROVIDER)
    end
  end
end
