# db/migrate/20260206102147_rename_conversations_prompts_outputs_to_chat_user_message_ai_message.rb
class RenameConversationsPromptsOutputsToChatUserMessageAiMessage < ActiveRecord::Migration[7.1]
  def up
    # We only remove foreign keys that reference columns we will rename.
    # Index renames are intentionally avoided (brittle + unnecessary).

    # prompts.conversation_id -> user_messages.chat_id (FK must be dropped before column rename)
    remove_foreign_key :prompts, :conversations

    # outputs.prompt_id -> ai_messages.user_message_id
    remove_foreign_key :outputs, :prompts

    # proposed_actions.output_id -> proposed_actions.ai_message_id
    remove_foreign_key :proposed_actions, :outputs

    # ---- Rename tables ----
    rename_table :conversations, :chats
    rename_table :prompts, :user_messages
    rename_table :outputs, :ai_messages

    # ---- Rename columns ----
    rename_column :user_messages, :conversation_id, :chat_id
    rename_column :ai_messages, :prompt_id, :user_message_id
    rename_column :proposed_actions, :output_id, :ai_message_id

    # ---- Re-add foreign keys with new table/column names ----
    add_foreign_key :user_messages, :chats, column: :chat_id
    add_foreign_key :ai_messages, :user_messages, column: :user_message_id
    add_foreign_key :proposed_actions, :ai_messages, column: :ai_message_id
  end

  def down
    # Drop the renamed foreign keys first
    remove_foreign_key :proposed_actions, :ai_messages
    remove_foreign_key :ai_messages, :user_messages
    remove_foreign_key :user_messages, :chats

    # Rename columns back
    rename_column :proposed_actions, :ai_message_id, :output_id
    rename_column :ai_messages, :user_message_id, :prompt_id
    rename_column :user_messages, :chat_id, :conversation_id

    # Rename tables back
    rename_table :ai_messages, :outputs
    rename_table :user_messages, :prompts
    rename_table :chats, :conversations

    # Restore original foreign keys
    add_foreign_key :prompts, :conversations
    add_foreign_key :outputs, :prompts
    add_foreign_key :proposed_actions, :outputs
  end
end
