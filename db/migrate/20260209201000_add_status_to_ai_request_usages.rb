class AddStatusToAiRequestUsages < ActiveRecord::Migration[7.1]
  def up
    add_column :ai_request_usages, :status, :string, null: false, default: "completed"
    add_column :ai_request_usages, :completed_at, :datetime
    add_index :ai_request_usages, :status

    execute <<~SQL.squish
      UPDATE ai_request_usages
      SET completed_at = requested_at
      WHERE completed_at IS NULL AND status = 'completed'
    SQL
  end

  def down
    remove_index :ai_request_usages, :status if index_exists?(:ai_request_usages, :status)
    remove_column :ai_request_usages, :completed_at if column_exists?(:ai_request_usages, :completed_at)
    remove_column :ai_request_usages, :status if column_exists?(:ai_request_usages, :status)
  end
end
