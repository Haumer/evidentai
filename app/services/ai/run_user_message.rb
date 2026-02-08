# app/services/ai/run_user_message.rb
#
# Orchestrator for processing a single UserMessage.
#
# Responsibilities:
# 1) Stream assistant chat reply (left pane)
# 2) Update artifact/output (right pane)
# 3) Extract proposed actions (under assistant)
#
# IMPORTANT:
# - This class orchestrates flow only.
# - Artifact HTML is owned by Artifact, not AiMessage.
# - All heavy logic is delegated to services.

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
      meta = extract_intent!(ai_message)

      if meta_should_generate_artifact?(meta)
        update_artifact!(ai_message)
      else
        keep_previous_artifact!
      end

      extract_actions!
    end

    private

    # ------------------------------------------------------------
    # Chat pipeline (streamed)
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
      Ai::Chat::Broadcast::ReplyBroadcaster
        .new(user_message: @user_message)
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
    # Intent / control metadata (non-streamed, JSON only)
    # ------------------------------------------------------------

    def extract_intent!(ai_message)
      Ai::Intent::Extract.new(
        user_message: @user_message,
        ai_message: ai_message,
        context: context_text,
        model: DEFAULT_MODEL,
        provider: DEFAULT_PROVIDER
      ).call
    rescue => _e
      nil
    end

    def meta_should_generate_artifact?(meta)
      return true if meta.nil? # fail-open to preserve existing behavior

      !!meta[:should_generate_artifact]
    end

    # ------------------------------------------------------------
    # Artifact pipeline (non-streamed)
    # ------------------------------------------------------------

    def keep_previous_artifact!
      # Calm default: do not change the right pane if the user is just chatting.
      previous_text = Ai::Artifacts::CurrentText.call(chat: @chat)
      artifact_broadcaster.replace(text: previous_text, status: "ready")
      run_status_broadcaster.ready
    rescue => _e
      # no-op
      nil
    end

    def update_artifact!(ai_message)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      run_status_broadcaster.working

      previous_text = Ai::Artifacts::CurrentText.call(chat: @chat)
      artifact_broadcaster.replace(text: previous_text, status: "working")

      # Generate new artifact HTML (string only)
      generated_text = generate_artifact_text(previous_text)

      extracted = Ai::ArtifactDatasetExtractor.call(generated_text)

      # Optional lightweight preview on AiMessage (non-authoritative)
      ai_message.update!(
        content: (ai_message.content || {}).merge("preview" => generated_text)
      ) rescue nil

      final_text = Ai::Artifacts::PersistAndPrepareText.call(
        chat: @chat,
        user_message: @user_message,
        generated_text: generated_text,
        dataset_json: extracted[:dataset_json],
        sources_json: extracted[:sources_json]
      )

      artifact_broadcaster.replace(text: final_text.to_s, status: "ready")

      elapsed_ms =
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000.0).round
      remaining_ms = MIN_OUTPUT_WORKING_MS - elapsed_ms
      sleep(remaining_ms / 1000.0) if remaining_ms.positive?

      run_status_broadcaster.ready
    rescue => e
      artifact_broadcaster.replace(
        text: "⚠️ Failed to generate output: #{e.message}",
        status: "ready"
      )
      run_status_broadcaster.ready rescue nil
    end

    def generate_artifact_text(previous_text)
      result = client.generate(
        prompt_snapshot: Ai::UpdateArtifact.messages(
          @user_message,
          current_artifact_text: previous_text
        ),
        model: DEFAULT_MODEL
      )

      result.fetch(:text).to_s
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
      Ai::ExtractProposedActions
        .new(user_message: @user_message, context: context_text)
        .call!
    end

    # ------------------------------------------------------------
    # AI client
    # ------------------------------------------------------------

    def client
      @client ||= Ai::Client.new(provider: DEFAULT_PROVIDER)
    end
  end
end
