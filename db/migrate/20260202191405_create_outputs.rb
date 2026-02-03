class CreateOutputs < ActiveRecord::Migration[7.1]
  def change
    create_table :outputs do |t|
      t.references :prompt, null: false, foreign_key: true
      t.string :kind
      t.jsonb :content
      t.string :status

      t.timestamps
    end
  end
end
