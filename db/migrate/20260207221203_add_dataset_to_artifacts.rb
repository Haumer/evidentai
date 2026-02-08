class AddDatasetToArtifacts < ActiveRecord::Migration[7.1]
  def change
    add_column :artifacts, :dataset_json, :jsonb
    add_column :artifacts, :sources_json, :jsonb
    add_column :artifacts, :dataset_locked_by_user, :boolean, default: false, null: false

    add_index :artifacts, :dataset_locked_by_user
  end
end
