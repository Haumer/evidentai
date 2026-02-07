# db/migrate/20260205140000_default_prompts_settings_to_empty_hash.rb
class DefaultPromptsSettingsToEmptyHash < ActiveRecord::Migration[7.1]
  def up
    change_column_default :prompts, :settings, from: nil, to: {}
    execute "UPDATE prompts SET settings = '{}'::jsonb WHERE settings IS NULL"
  end

  def down
    execute "UPDATE prompts SET settings = NULL WHERE settings = '{}'::jsonb"
    change_column_default :prompts, :settings, from: {}, to: nil
  end
end
