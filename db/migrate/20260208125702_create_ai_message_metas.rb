class CreateAiMessageMetas < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_message_metas do |t|
      t.references :ai_message, null: false, foreign_key: true

      # Common, queryable intent flags
      t.string  :suggested_title
      t.boolean :should_generate_artifact
      t.boolean :needs_sources
      t.boolean :suggest_web_search

      # Extended control-plane payload
      t.jsonb :payload_json, null: false, default: {}
      t.jsonb :flags_json, null: false, default: {}

      t.timestamps
    end
  end
end
