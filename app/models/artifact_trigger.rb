class ArtifactTrigger < ApplicationRecord
  TRIGGER_TYPES = %w[manual api email file].freeze
  STATUSES = %w[active paused].freeze

  MIN_CONTEXT_TURNS = 1
  MAX_CONTEXT_TURNS = 30
  MIN_CONTEXT_MAX_CHARS = 500
  MAX_CONTEXT_MAX_CHARS = 20_000

  belongs_to :company
  belongs_to :created_by, class_name: "User"
  belongs_to :chat
  belongs_to :artifact

  validates :name, presence: true
  validates :trigger_type, presence: true, inclusion: { in: TRIGGER_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :context_turns, numericality: { only_integer: true, greater_than_or_equal_to: MIN_CONTEXT_TURNS, less_than_or_equal_to: MAX_CONTEXT_TURNS }
  validates :context_max_chars, numericality: { only_integer: true, greater_than_or_equal_to: MIN_CONTEXT_MAX_CHARS, less_than_or_equal_to: MAX_CONTEXT_MAX_CHARS }
  validate :artifact_and_chat_belong_together

  before_validation :normalize_values!
  before_validation :ensure_api_token!

  def active?
    status == "active"
  end

  def enqueue_run!(input_text:, fired_by:, context_turns: nil, context_max_chars: nil, source: nil)
    raise ArgumentError, "Trigger is paused" unless active?

    turns = clamp_turns(context_turns || self.context_turns)
    max_chars = clamp_max_chars(context_max_chars || self.context_max_chars)
    instruction = build_instruction(input_text: input_text, source: source)

    user_message = chat.user_messages.create!(
      company: company,
      created_by: fired_by || created_by,
      instruction: instruction,
      status: "queued",
      settings: {
        "context_turns" => turns,
        "context_max_chars" => max_chars,
        "trigger" => {
          "id" => id,
          "name" => name,
          "trigger_type" => trigger_type
        }
      }
    )

    SubmitUserMessageJob.perform_later(user_message.id)
    touch_fired_counters!
    user_message
  end

  def build_instruction(input_text:, source: nil)
    base_request = instruction_template.to_s.strip.presence || latest_user_instruction
    source_label = source.to_s.strip.presence || trigger_type
    extra_context = input_text.to_s.strip

    lines = []
    lines << base_request if base_request.present?
    lines << "Regenerate the artifact using the latest chat context window."
    lines << "Trigger source: #{source_label}."
    lines << "New context:\n#{extra_context}" if extra_context.present?

    lines.join("\n\n").strip
  end

  private

  def normalize_values!
    self.trigger_type = trigger_type.to_s.downcase.strip
    self.status = status.to_s.downcase.strip
    self.context_turns = clamp_turns(context_turns)
    self.context_max_chars = clamp_max_chars(context_max_chars)
    self.metadata = {} unless metadata.is_a?(Hash)
  end

  def ensure_api_token!
    return if api_token.present?

    self.api_token = SecureRandom.hex(24)
  end

  def latest_user_instruction
    chat.user_messages.order(created_at: :desc).limit(1).pluck(:instruction).first.to_s.strip
  end

  def touch_fired_counters!
    update_columns(
      last_fired_at: Time.current,
      fired_count: fired_count.to_i + 1,
      updated_at: Time.current
    )
  end

  def clamp_turns(value)
    value.to_i.clamp(MIN_CONTEXT_TURNS, MAX_CONTEXT_TURNS)
  end

  def clamp_max_chars(value)
    value.to_i.clamp(MIN_CONTEXT_MAX_CHARS, MAX_CONTEXT_MAX_CHARS)
  end

  def artifact_and_chat_belong_together
    return if artifact.blank? || chat.blank? || company.blank?

    errors.add(:chat, "must match artifact chat") if artifact.chat_id != chat_id
    errors.add(:company, "must match artifact company") if artifact.company_id != company_id
  end
end
