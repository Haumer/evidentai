# app/models/artifact.rb
class Artifact < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: "User"
  belongs_to :chat

  # Right-side output (compiled / refined result)
  #
  # content: markdown (or structured text later)
  # kind: optional classifier (e.g. "daily_brief", "report", "dashboard")
  # status: draft / ready / archived (optional, app-defined)

  validates :content, presence: true, allow_blank: true
end
