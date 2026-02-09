# app/models/artifact.rb
class Artifact < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: "User"
  belongs_to :chat

  has_many :artifact_triggers, dependent: :destroy

  validates :content, presence: true, allow_blank: true

  MAX_DATASET_BYTES = 200_000 # tune

  def dataset_present?
    respond_to?(:dataset_json) && dataset_json.present?
  end

  def datasets
    (dataset_json || {}).fetch("datasets", [])
  rescue
    []
  end

  def dataset_at(index)
    datasets[index.to_i]
  end

  def update_dataset_cell!(dataset_index:, row_index:, col_index:, value:)
    dj = dataset_json.presence || { "version" => 1, "datasets" => [] }

    d_i = dataset_index.to_i
    r_i = row_index.to_i
    c_i = col_index.to_i

    raise ArgumentError, "Dataset not found" unless dj["datasets"].is_a?(Array) && dj["datasets"][d_i].is_a?(Hash)

    rows = dj["datasets"][d_i]["rows"]
    raise ArgumentError, "Rows not found" unless rows.is_a?(Array) && rows[r_i].is_a?(Array)

    old = rows[r_i][c_i]
    raw = value.to_s.strip

    new_value =
      if old.is_a?(Numeric)
        parse_numeric_cell(raw)
      else
        raw
      end

    rows[r_i][c_i] = new_value

    raise ArgumentError, "Dataset too large" if dj.to_json.bytesize > MAX_DATASET_BYTES

    update!(
      dataset_json: dj,
      dataset_locked_by_user: true
    )
  end

  private

  # Prefer integers when possible so "100" remains 100 (not 100.0).
  def parse_numeric_cell(str)
    return nil if str == ""

    # Integer?
    return Integer(str, 10) if str.match?(/\A-?\d+\z/)

    # Float?
    return Float(str) if str.match?(/\A-?\d+(?:\.\d+)?\z/)

    raise ArgumentError, "Invalid number"
  rescue ArgumentError
    raise ArgumentError, "Invalid number"
  end
end
