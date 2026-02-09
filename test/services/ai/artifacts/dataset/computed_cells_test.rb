require "test_helper"

class AiArtifactsDatasetComputedCellsTest < ActiveSupport::TestCase
  test "applies computed columns using spreadsheet refs" do
    dataset_json = {
      "version" => 1,
      "datasets" => [
        {
          "name" => "PnL",
          "schema" => ["Revenue", "Cost", "Profit"],
          "rows" => [
            [120, 30, nil],
            [80, 95, nil]
          ],
          "computed_columns" => [
            { "index" => 2, "formula" => "A - B" }
          ]
        }
      ]
    }

    result = Ai::Artifacts::Dataset::ComputedCells.apply(dataset_json)
    rows = result.dig("datasets", 0, "rows")

    assert_equal [[120, 30, 90], [80, 95, -15]], rows
  end

  test "sets computed cell to nil when formula cannot be evaluated" do
    dataset_json = {
      "version" => 1,
      "datasets" => [
        {
          "name" => "Ratio",
          "schema" => ["A", "B", "C"],
          "rows" => [
            [10, 0, nil],
            [10, "oops", nil]
          ],
          "computed_columns" => [
            { "column" => "C", "formula" => "A / B" }
          ]
        }
      ]
    }

    result = Ai::Artifacts::Dataset::ComputedCells.apply(dataset_json)
    rows = result.dig("datasets", 0, "rows")

    assert_equal [[10, 0, nil], [10, "oops", nil]], rows
  end
end
