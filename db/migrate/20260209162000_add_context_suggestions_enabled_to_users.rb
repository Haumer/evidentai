class AddContextSuggestionsEnabledToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :context_suggestions_enabled, :boolean, null: false, default: true
    add_index :users, :context_suggestions_enabled
  end
end
