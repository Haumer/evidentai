class KeepAiUsageHistoryWhenChatsAreDeleted < ActiveRecord::Migration[7.1]
  def up
    remove_foreign_key :ai_request_usages, :chats if foreign_key_exists?(:ai_request_usages, :chats)
  end

  def down
    return if foreign_key_exists?(:ai_request_usages, :chats)

    add_foreign_key :ai_request_usages, :chats
  end
end
