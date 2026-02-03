class CreateAttachments < ActiveRecord::Migration[7.1]
  def change
    create_table :attachments do |t|
      t.references :company, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :attachable, polymorphic: true, null: false
      t.string :kind
      t.string :title
      t.text :body
      t.jsonb :metadata
      t.string :status

      t.timestamps
    end
  end
end
