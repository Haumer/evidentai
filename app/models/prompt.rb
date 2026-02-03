class Prompt < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: "User"
  belongs_to :conversation, optional: true # remove optional once null: false

  has_many :attachments, as: :attachable, dependent: :destroy
  has_one :output, dependent: :destroy
end