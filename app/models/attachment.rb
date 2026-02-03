class Attachment < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: "User"
  belongs_to :attachable, polymorphic: true
end