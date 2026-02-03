json.extract! output, :id, :prompt_id, :kind, :content, :status, :created_at, :updated_at
json.url output_url(output, format: :json)
