json.extract! attachment, :id, :company_id, :created_by_id, :attachable_id, :attachable_type, :kind, :title, :body, :metadata, :status, :created_at, :updated_at
json.url attachment_url(attachment, format: :json)
