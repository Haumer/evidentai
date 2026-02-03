json.extract! conversation, :id, :company_id, :created_by_id, :title, :status, :created_at, :updated_at
json.url conversation_url(conversation, format: :json)
