# app/models/artifact.rb
class Artifact < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: "User"
  belongs_to :chat

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

  def computed_column_indexes(dataset_index:)
    dataset = dataset_at(dataset_index)
    return [] unless dataset.is_a?(Hash)

    Ai::Artifacts::Dataset::ComputedCells.computed_column_indexes(dataset)
  rescue
    []
  end

  def computed_cell?(dataset_index:, col_index:)
    computed_column_indexes(dataset_index: dataset_index).include?(col_index.to_i)
  end

  def update_dataset_cell!(dataset_index:, row_index:, col_index:, value:)
    dj = dataset_json.presence || { "version" => 1, "datasets" => [] }

    d_i = dataset_index.to_i
    r_i = row_index.to_i
    c_i = col_index.to_i

    raise ArgumentError, "Dataset not found" unless dj["datasets"].is_a?(Array) && dj["datasets"][d_i].is_a?(Hash)

    dataset = dj["datasets"][d_i]
    rows = dataset["rows"]
    raise ArgumentError, "Rows not found" unless rows.is_a?(Array) && rows[r_i].is_a?(Array)
    raise ArgumentError, "Cell not found" unless c_i >= 0 && c_i < rows[r_i].length

    computed_columns = Ai::Artifacts::Dataset::ComputedCells.computed_column_indexes(dataset)
    raise ArgumentError, "Computed cell is read-only" if computed_columns.include?(c_i)

    old = rows[r_i][c_i]
    raw = value.to_s.strip

    new_value =
      if old.is_a?(Numeric)
        parse_numeric_cell(raw)
      else
        raw
      end

    rows[r_i][c_i] = new_value
    dj = Ai::Artifacts::Dataset::ComputedCells.apply(dj)

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
