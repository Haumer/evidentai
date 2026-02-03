# app/jobs/submit_prompt_job.rb
class SubmitPromptJob < ApplicationJob
  queue_as :default

  FLUSH_EVERY_SECONDS = 0.10
  FLUSH_EVERY_CHARS   = 80

  def perform(prompt_id)
    prompt = Prompt.find(prompt_id)

    # Start with ghost (assistant_stream shows ghost when text is blank)
    broadcast_stream_text(prompt: prompt, text: "")

    last_flush_at = Time.current
    last_flushed_len = 0

    # IMPORTANT: accept only delta:, accumulated:
    Ai::StreamSubmitPrompt.new(prompt: prompt).call do |delta:, accumulated:|
      now = Time.current
      should_flush_time = (now - last_flush_at) >= FLUSH_EVERY_SECONDS
      should_flush_size = (accumulated.length - last_flushed_len) >= FLUSH_EVERY_CHARS

      next unless should_flush_time || should_flush_size

      broadcast_stream_text(prompt: prompt, text: accumulated)

      last_flush_at = now
      last_flushed_len = accumulated.length
    end

    prompt.reload

    # Final replace: full assistant view (text + actions)
    Turbo::StreamsChannel.broadcast_replace_to(
      prompt.conversation,
      target: "assistant_prompt_#{prompt.id}",
      partial: "prompts/assistant",
      locals: { prompt: prompt }
    )
  rescue => e
    prompt.update!(status: "failed", error_message: e.message) if prompt&.persisted?

    Turbo::StreamsChannel.broadcast_replace_to(
      prompt.conversation,
      target: "assistant_prompt_#{prompt.id}",
      partial: "prompts/assistant",
      locals: { prompt: prompt }
    )
  end

  private

  def broadcast_stream_text(prompt:, text:)
    Turbo::StreamsChannel.broadcast_replace_to(
      prompt.conversation,
      target: "assistant_prompt_#{prompt.id}",
      partial: "prompts/assistant_stream",
      locals: { prompt: prompt, text: text.to_s }
    )
  end
end
