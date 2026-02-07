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
      text = generate_artifact_text

      # Store preview on the ai_message (best-effort)
      ai_message.update!(
        content: (ai_message.content || {}).merge("preview" => text)
      ) rescue nil

      # UX: broadcast final output ASAP
      artifact_broadcaster.replace(text: text, status: "ready")

      # Ensure the "working" indicator is visible for a beat (calm UX).
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000.0).round
      remaining_ms = MIN_OUTPUT_WORKING_MS - elapsed_ms
      sleep(remaining_ms / 1000.0) if remaining_ms.positive?

      # Mark ready in chat now that artifact is rendered.
      run_status_broadcaster.ready

      # Persistence should not block UI updates.
      persist_artifact!(text)
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
      artifact = Artifact.find_by(chat: @chat)
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

    def persist_artifact!(text)
      artifact = Artifact.find_or_initialize_by(chat: @chat)

      if artifact.respond_to?(:company=) && artifact.company.blank? && @user_message.respond_to?(:company)
        artifact.company = @user_message.company
      end

      if artifact.respond_to?(:created_by=) && artifact.created_by.blank? && @user_message.respond_to?(:created_by)
        artifact.created_by = @user_message.created_by
      end

      if artifact.respond_to?(:user=) && artifact.user.blank? && @user_message.respond_to?(:created_by)
        artifact.user = @user_message.created_by
      end

      artifact.assign_attributes(artifact_content_attributes(text))
      artifact.save!
    rescue => e
      Rails.logger.warn("[Ai::RunUserMessage] Artifact persist failed: #{e.class}: #{e.message}")
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
