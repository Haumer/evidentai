class CreatePrompts < ActiveRecord::Migration[7.1]
  def change
    create_table :prompts do |t|
      t.references :company, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.text :instruction
      t.string :status
      t.datetime :frozen_at
      t.string :llm_provider
      t.string :llm_model
      t.text :prompt_snapshot
      t.jsonb :settings

      t.timestamps
    end
  end
end
