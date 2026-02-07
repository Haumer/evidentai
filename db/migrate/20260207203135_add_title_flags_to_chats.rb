class AddTitleFlagsToChats < ActiveRecord::Migration[7.1]
  def change
    add_column :chats, :title_set_by_user, :boolean, null: false, default: false
    add_column :chats, :title_generated_at, :datetime
  end
end