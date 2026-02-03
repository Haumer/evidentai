class AddErrorMessageToPrompts < ActiveRecord::Migration[7.0]
  def change
    add_column :prompts, :error_message, :string
  end
end
