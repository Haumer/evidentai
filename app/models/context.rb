class Context < ApplicationRecord
  belongs_to :company
  belongs_to :created_by
end
