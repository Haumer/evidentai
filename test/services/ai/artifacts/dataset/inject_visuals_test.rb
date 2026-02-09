require "test_helper"

class AiArtifactsDatasetInjectVisualsTest < ActiveSupport::TestCase
  test "injects deterministic chart section for numeric columns" do
    html = <<~HTML
      <html>
        <head><title>Artifact</title></head>
        <body>
          <h1>Revenue</h1>
        </body>
      </html>
    HTML

    dataset_json = {
      "version" => 1,
      "datasets" => [
        {
          "name" => "Q1",
          "schema" => ["Month", "Revenue", "Cost"],
          "rows" => [
            ["Jan", 10, 3],
            ["Feb", 12, 5]
          ]
        }
      ]
    }

    output = Ai::Artifacts::Dataset::InjectVisuals.call(html: html, dataset_json: dataset_json)
    doc = Nokogiri::HTML(output)

    section = doc.at_css("section#artifact_dataset_visuals")
    assert section.present?
    assert_includes section.text, "Charts"
    assert_includes section.text, "Revenue"
    assert_includes section.text, "Cost"
    assert_equal 4, section.css(".bar-row").size
  end

  test "replaces previous visuals section instead of duplicating it" do
    html = <<~HTML
      <html>
        <head></head>
        <body>
          <section id="artifact_dataset_visuals"><p>Old</p></section>
        </body>
      </html>
    HTML

    dataset_json = {
      "version" => 1,
      "datasets" => [
        {
          "name" => "Single",
          "schema" => ["Label", "Value"],
          "rows" => [["A", 1]]
        }
      ]
    }

    output = Ai::Artifacts::Dataset::InjectVisuals.call(html: html, dataset_json: dataset_json)
    doc = Nokogiri::HTML(output)

    assert_equal 1, doc.css("section#artifact_dataset_visuals").size
    refute_includes doc.text, "Old"
  end
end
