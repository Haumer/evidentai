require "test_helper"
require "securerandom"

class ArtifactTest < ActiveSupport::TestCase
  test "update_dataset_cell recomputes derived columns and locks dataset" do
    artifact = build_artifact_with_computed_dataset

    artifact.update_dataset_cell!(
      dataset_index: 0,
      row_index: 0,
      col_index: 0,
      value: "140"
    )

    rows = artifact.reload.dataset_json.dig("datasets", 0, "rows")
    assert_equal [140, 30, 110], rows[0]
    assert artifact.dataset_locked_by_user
  end

  test "update_dataset_cell rejects edits to computed columns" do
    artifact = build_artifact_with_computed_dataset

    error = assert_raises(ArgumentError) do
      artifact.update_dataset_cell!(
        dataset_index: 0,
        row_index: 0,
        col_index: 2,
        value: "999"
      )
    end

    assert_equal "Computed cell is read-only", error.message
  end

  private

  def build_artifact_with_computed_dataset
    company = Company.create!(name: "Acme", slug: "acme-#{SecureRandom.hex(4)}", status: "active")
    user = User.create!(email: "artifact-#{SecureRandom.hex(4)}@example.com", password: "password123")
    chat = Chat.create!(company: company, created_by: user, status: "active", title: "Data Chat")

    Artifact.create!(
      company: company,
      created_by: user,
      chat: chat,
      content: "<html><head></head><body><h1>Demo</h1></body></html>",
      dataset_json: {
        "version" => 1,
        "datasets" => [
          {
            "name" => "P&L",
            "schema" => ["Revenue", "Cost", "Profit"],
            "rows" => [
              [120, 30, nil],
              [80, 50, nil]
            ],
            "computed_columns" => [
              { "index" => 2, "formula" => "A - B" }
            ]
          }
        ]
      }
    )
  end
end
