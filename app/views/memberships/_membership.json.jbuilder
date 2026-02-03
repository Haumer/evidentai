json.extract! membership, :id, :user_id, :company_id, :role, :status, :created_at, :updated_at
json.url membership_url(membership, format: :json)
