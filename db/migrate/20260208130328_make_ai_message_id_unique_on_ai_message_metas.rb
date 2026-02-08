class MakeAiMessageIdUniqueOnAiMessageMetas < ActiveRecord::Migration[7.1]
  def change
    # Rails created a non-unique index for t.references :ai_message by default.
    # We want a strict 1:1 relationship, so enforce uniqueness at the DB level.
    remove_index :ai_message_metas, :ai_message_id
    add_index :ai_message_metas, :ai_message_id, unique: true
  end
end