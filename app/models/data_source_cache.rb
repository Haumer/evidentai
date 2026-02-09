class DataSourceCache < ApplicationRecord
  belongs_to :company
  belongs_to :chat

  validates :query_signature, presence: true
  validates :query_text, presence: true
  validates :query_signature, uniqueness: { scope: :chat_id }
end
