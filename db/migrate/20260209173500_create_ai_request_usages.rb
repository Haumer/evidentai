class CreateAiRequestUsages < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_request_usages do |t|
      t.references :company, null: false, foreign_key: true
      t.references :chat, null: false, foreign_key: true
      t.references :user_message, null: true, foreign_key: true
      t.references :ai_message, null: true, foreign_key: true

      t.string :request_kind, null: false
      t.string :provider, null: false
      t.string :model
      t.string :provider_request_id

      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.integer :total_tokens, null: false, default: 0

      t.decimal :input_rate_per_1m_usd, precision: 12, scale: 6
      t.decimal :output_rate_per_1m_usd, precision: 12, scale: 6
      t.decimal :input_cost_usd, precision: 12, scale: 6, null: false, default: 0
      t.decimal :output_cost_usd, precision: 12, scale: 6, null: false, default: 0
      t.decimal :total_cost_usd, precision: 12, scale: 6, null: false, default: 0

      t.datetime :requested_at, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :ai_request_usages, :request_kind
    add_index :ai_request_usages, :requested_at
    add_index :ai_request_usages, [:chat_id, :requested_at]
    add_index :ai_request_usages, [:user_message_id, :requested_at]
  end
end
