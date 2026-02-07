class CreateProposedActions < ActiveRecord::Migration[7.0]
  def change
    create_table :proposed_actions do |t|
      t.references :output, null: false, foreign_key: true

      t.string :action_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "proposed"

      t.datetime :approved_at
      t.references :approved_by, null: true, foreign_key: { to_table: :users }

      t.datetime :dismissed_at
      t.references :dismissed_by, null: true, foreign_key: { to_table: :users }

      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :proposed_actions, :status
    add_index :proposed_actions, [:output_id, :status]
    add_index :proposed_actions, :action_type
  end
end