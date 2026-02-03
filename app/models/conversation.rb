class Conversation < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: "User"

  has_many :prompts, dependent: :destroy
end
