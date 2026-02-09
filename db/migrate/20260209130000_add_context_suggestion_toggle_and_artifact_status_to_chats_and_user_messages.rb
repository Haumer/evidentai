class AddContextSuggestionToggleAndArtifactStatusToChatsAndUserMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :chats, :context_suggestions_enabled, :boolean, null: false, default: true
    add_index :chats, :context_suggestions_enabled

    add_column :user_messages, :artifact_updated_at, :datetime
    add_index :user_messages, :artifact_updated_at
  end
end
