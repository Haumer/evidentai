class AddConversationToPrompts < ActiveRecord::Migration[7.1]
  def change
    add_reference :prompts, :conversation, null: false, foreign_key: true
  end
end
