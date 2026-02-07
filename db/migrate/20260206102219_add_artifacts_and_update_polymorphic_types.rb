# db/migrate/20260206101000_add_artifacts_and_update_polymorphic_types.rb
class AddArtifactsAndUpdatePolymorphicTypes < ActiveRecord::Migration[7.1]
  def up
    create_table :artifacts do |t|
      t.bigint :company_id, null: false
      t.bigint :created_by_id, null: false
      t.bigint :chat_id, null: false

      t.string :kind # optional but useful: "daily_brief", "dashboard", etc.
      t.text :content # markdown (right panel)
      t.string :status
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :artifacts, :company_id
    add_index :artifacts, :created_by_id
    add_index :artifacts, :chat_id
    add_index :artifacts, [:chat_id, :created_at]

    add_foreign_key :artifacts, :companies
    add_foreign_key :artifacts, :users, column: :created_by_id
    add_foreign_key :artifacts, :chats, column: :chat_id

    # ---- Update polymorphic type strings for existing records ----
    execute <<~SQL
      UPDATE attachments
      SET attachable_type = 'Chat'
      WHERE attachable_type = 'Conversation';
    SQL

    execute <<~SQL
      UPDATE attachments
      SET attachable_type = 'UserMessage'
      WHERE attachable_type = 'Prompt';
    SQL

    execute <<~SQL
      UPDATE attachments
      SET attachable_type = 'AiMessage'
      WHERE attachable_type = 'Output';
    SQL

    # ActionText polymorphic types (only if you actually used them on these records)
    execute <<~SQL
      UPDATE action_text_rich_texts
      SET record_type = 'Chat'
      WHERE record_type = 'Conversation';
    SQL

    execute <<~SQL
      UPDATE action_text_rich_texts
      SET record_type = 'UserMessage'
      WHERE record_type = 'Prompt';
    SQL

    execute <<~SQL
      UPDATE action_text_rich_texts
      SET record_type = 'AiMessage'
      WHERE record_type = 'Output';
    SQL
  end

  def down
    # revert polymorphic type strings
    execute <<~SQL
      UPDATE attachments
      SET attachable_type = 'Conversation'
      WHERE attachable_type = 'Chat';
    SQL

    execute <<~SQL
      UPDATE attachments
      SET attachable_type = 'Prompt'
      WHERE attachable_type = 'UserMessage';
    SQL

    execute <<~SQL
      UPDATE attachments
      SET attachable_type = 'Output'
      WHERE attachable_type = 'AiMessage';
    SQL

    execute <<~SQL
      UPDATE action_text_rich_texts
      SET record_type = 'Conversation'
      WHERE record_type = 'Chat';
    SQL

    execute <<~SQL
      UPDATE action_text_rich_texts
      SET record_type = 'Prompt'
      WHERE record_type = 'UserMessage';
    SQL

    execute <<~SQL
      UPDATE action_text_rich_texts
      SET record_type = 'Output'
      WHERE record_type = 'AiMessage';
    SQL

    drop_table :artifacts
  end
end
