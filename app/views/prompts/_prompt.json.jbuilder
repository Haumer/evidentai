json.extract! prompt, :id, :company_id, :created_by_id, :instruction, :status, :frozen_at, :llm_provider, :llm_model, :prompt_snapshot, :settings, :created_at, :updated_at
json.url prompt_url(prompt, format: :json)
