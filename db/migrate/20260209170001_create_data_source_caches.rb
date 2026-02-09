class CreateDataSourceCaches < ActiveRecord::Migration[7.1]
  def change
    create_table :data_source_caches do |t|
      t.references :company, null: false, foreign_key: true
      t.references :chat, null: false, foreign_key: true
      t.string :query_signature, null: false
      t.text :query_text, null: false
      t.jsonb :data_json, null: false, default: {}
      t.jsonb :sources_json, null: false, default: []
      t.datetime :last_fetched_at, null: false

      t.timestamps
    end

    add_index :data_source_caches, [:chat_id, :query_signature], unique: true
    add_index :data_source_caches, :last_fetched_at
  end
end
