json.extract! company, :id, :name, :slug, :status, :created_at, :updated_at
json.url company_url(company, format: :json)
