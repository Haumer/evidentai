# app/services/ai/artifacts/dataset/inject_visuals.rb
#
# Injects deterministic, non-JS visuals driven by dataset_json.
# This guarantees charts inside the iframe can be refreshed from edited data
# without any iframe-originated requests or script execution.

module Ai
  module Artifacts
    module Dataset
      class InjectVisuals
        MAX_DATASETS = 6
        MAX_CHARTS_PER_DATASET = 4
        MAX_ROWS_PER_CHART = 40

        def self.call(html:, dataset_json:)
          new(html: html, dataset_json: dataset_json).call
        end

        def initialize(html:, dataset_json:)
          @html = html.to_s
          @dataset_json = dataset_json
        end

        def call
          return @html if @html.blank?
          return @html if @dataset_json.blank?

          datasets = extract_datasets(@dataset_json).first(MAX_DATASETS)
          return @html if datasets.empty?

          doc = Nokogiri::HTML(@html)
          body = doc.at("body") || doc.root
          return @html unless body

          existing = doc.at_css("section#artifact_dataset_visuals")
          existing&.remove

          section = Nokogiri::XML::Node.new("section", doc)
          section["id"] = "artifact_dataset_visuals"
          section["class"] = "artifact-visuals"

          style = Nokogiri::XML::Node.new("style", doc)
          style.content = <<~CSS
            .artifact-visuals{border:1px solid #e5e7eb;border-radius:12px;padding:16px;margin:16px 0;background:#fff}
            .artifact-visuals h2{font-size:14px;line-height:1.3;margin:0 0 10px 0;font-weight:700}
            .artifact-visuals .ds{margin-top:14px}
            .artifact-visuals .ds h3{font-size:13px;margin:0 0 8px 0;font-weight:700}
            .artifact-visuals .chart{margin-top:10px}
            .artifact-visuals .chart-title{font-size:12px;font-weight:700;color:#374151;margin:0 0 8px 0}
            .artifact-visuals .bar-row{display:grid;grid-template-columns:minmax(80px,160px) 1fr auto;gap:8px;align-items:center;margin:6px 0}
            .artifact-visuals .bar-label{font-size:12px;color:#4b5563;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
            .artifact-visuals .bar-track{height:10px;border-radius:999px;background:#eef2ff;overflow:hidden}
            .artifact-visuals .bar-fill{display:block;height:100%;background:linear-gradient(90deg,#3b82f6,#2563eb)}
            .artifact-visuals .bar-fill.is-negative{background:linear-gradient(90deg,#f97316,#ea580c)}
            .artifact-visuals .bar-value{font-size:12px;color:#374151;font-variant-numeric:tabular-nums}
            .artifact-visuals .empty{font-size:12px;color:#6b7280;margin:0}
          CSS
          section.add_child(style)

          h2 = Nokogiri::XML::Node.new("h2", doc)
          h2.content = "Charts"
          section.add_child(h2)

          has_any_chart = false

          datasets.each_with_index do |dataset, dataset_index|
            dataset_node, rendered = render_dataset(doc, dataset, dataset_index)
            next unless rendered

            has_any_chart = true
            section.add_child(dataset_node)
          end

          return @html unless has_any_chart

          body.add_child(section)
          doc.to_html
        rescue => e
          Rails.logger.info("[Ai::Artifacts::Dataset::InjectVisuals] failed: #{e.class}: #{e.message}")
          @html
        end

        private

        def render_dataset(doc, dataset, dataset_index)
          schema = Array(dataset["schema"])
          rows = Array(dataset["rows"]).select { |row| row.is_a?(Array) }.first(MAX_ROWS_PER_CHART)
          return [nil, false] if schema.empty? || rows.empty?

          numeric_columns = numeric_column_indexes(rows, schema.length).first(MAX_CHARTS_PER_DATASET)
          return [nil, false] if numeric_columns.empty?

          label_index = label_column_index(schema.length, numeric_columns)

          wrap = Nokogiri::XML::Node.new("div", doc)
          wrap["class"] = "ds"
          wrap["data-dataset-index"] = dataset_index.to_s

          title = Nokogiri::XML::Node.new("h3", doc)
          title.content = dataset["name"].to_s.presence || "Dataset #{dataset_index + 1}"
          wrap.add_child(title)

          numeric_columns.each do |col_index|
            chart = Nokogiri::XML::Node.new("div", doc)
            chart["class"] = "chart"
            chart["data-column-index"] = col_index.to_s

            chart_title = Nokogiri::XML::Node.new("p", doc)
            chart_title["class"] = "chart-title"
            chart_title.content = schema[col_index].to_s.presence || "Column #{col_index + 1}"
            chart.add_child(chart_title)

            points = rows.map do |row|
              label = row[label_index].to_s
              value = coerce_numeric(row[col_index])
              { label: label.presence || "Row", value: value }
            end.select { |p| p[:value].is_a?(Numeric) }

            if points.empty?
              empty = Nokogiri::XML::Node.new("p", doc)
              empty["class"] = "empty"
              empty.content = "No numeric values to plot."
              chart.add_child(empty)
              wrap.add_child(chart)
              next
            end

            max_abs = points.map { |p| p[:value].abs }.max.to_f
            max_abs = 1.0 if max_abs <= 0.0

            points.each do |point|
              row_node = Nokogiri::XML::Node.new("div", doc)
              row_node["class"] = "bar-row"

              label = Nokogiri::XML::Node.new("span", doc)
              label["class"] = "bar-label"
              label.content = point[:label]
              row_node.add_child(label)

              track = Nokogiri::XML::Node.new("span", doc)
              track["class"] = "bar-track"
              fill = Nokogiri::XML::Node.new("span", doc)
              fill["class"] = point[:value].negative? ? "bar-fill is-negative" : "bar-fill"
              pct = ((point[:value].abs / max_abs) * 100.0).round(2)
              fill["style"] = "width: #{pct}%"
              track.add_child(fill)
              row_node.add_child(track)

              value = Nokogiri::XML::Node.new("span", doc)
              value["class"] = "bar-value"
              value.content = format_number(point[:value])
              row_node.add_child(value)

              chart.add_child(row_node)
            end

            wrap.add_child(chart)
          end

          [wrap, true]
        end

        def extract_datasets(obj)
          h = obj.is_a?(Hash) ? obj : {}
          arr = h["datasets"] || h[:datasets]
          return [] unless arr.is_a?(Array)

          arr.select { |dataset| dataset.is_a?(Hash) }
        end

        def numeric_column_indexes(rows, schema_size)
          (0...schema_size).select do |col_index|
            values = rows.map { |row| coerce_numeric(row[col_index]) }.compact
            values.any?
          end
        end

        def label_column_index(schema_size, numeric_columns)
          candidates = (0...schema_size).to_a - numeric_columns
          candidates.first || 0
        end

        def coerce_numeric(value)
          return value.to_f if value.is_a?(Numeric)

          str = value.to_s.strip
          return nil if str.blank?
          return str.to_f if str.match?(/\A-?\d+(?:\.\d+)?\z/)

          nil
        end

        def format_number(value)
          return value.to_i.to_s if value.to_f == value.to_i.to_f

          value.round(4).to_s
        end
      end
    end
  end
end
