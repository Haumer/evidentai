class CreateArtifactTriggers < ActiveRecord::Migration[7.1]
  def change
    create_table :artifact_triggers do |t|
      t.references :company, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :chat, null: false, foreign_key: true
      t.references :artifact, null: false, foreign_key: true

      t.string :name, null: false
      t.string :trigger_type, null: false, default: "manual"
      t.string :status, null: false, default: "active"
      t.text :instruction_template
      t.integer :context_turns, null: false, default: 6
      t.integer :context_max_chars, null: false, default: 6000
      t.string :api_token
      t.datetime :last_fired_at
      t.integer :fired_count, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :artifact_triggers, :trigger_type
    add_index :artifact_triggers, :status
    add_index :artifact_triggers, :api_token, unique: true
  end
end
