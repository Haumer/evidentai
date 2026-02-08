class AiMessageMeta < ApplicationRecord
  # Avoid Rails inflection quirks around "meta" without global config changes.
  self.table_name = "ai_message_metas"

  belongs_to :ai_message

  validates :ai_message_id, uniqueness: true
end