class ContextItem < ApplicationRecord
  belongs_to :company
  belongs_to :context
  belongs_to :created_by
end
