# app/services/ai/artifact_dataset_table_injector.rb
#
# Injects a human-readable HTML representation of dataset_json into the artifact HTML.
#
# Why:
# - Dataset JSON is inert and kept out of the iframe (stripper).
# - The artifact iframe must still visibly reflect user edits without JS.
# - This service creates/updates a stable section inside the artifact HTML so edits
#   immediately change what the iframe renders.
#
# Output:
# - A section appended to <body>:
#     <section id="artifact_dataset_tables"> ... </section>
#
# Security posture:
# - Server-side only, Nokogiri manipulation
# - Escapes all cell values as text (no HTML injection)
# - Fail closed: returns original html on any error

module Ai
  class ArtifactDatasetTableInjector
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

      datasets = extract_datasets(@dataset_json)
      return @html if datasets.empty?

      doc = Nokogiri::HTML(@html)

      body = doc.at("body") || doc.root
      return @html unless body

      # Replace existing section if present
      existing = doc.at_css("section#artifact_dataset_tables")
      existing&.remove

      section = Nokogiri::XML::Node.new("section", doc)
      section["id"] = "artifact_dataset_tables"
      section["class"] = "artifact-datasets"

      # Minimal inline styles to look acceptable even without the main app CSS.
      # (This is inside the artifact HTML, so it must stand alone.)
      style = Nokogiri::XML::Node.new("style", doc)
      style.content = <<~CSS
        .artifact-datasets{border:1px solid #e5e7eb;border-radius:12px;padding:16px;margin:16px 0}
        .artifact-datasets h2{font-size:14px;margin:0 0 10px 0;font-weight:700}
        .artifact-datasets .ds{margin-top:14px}
        .artifact-datasets .ds h3{font-size:13px;margin:0 0 8px 0;font-weight:700}
        .artifact-datasets .meta{color:#6b7280;font-size:12px;margin:0 0 10px 0}
        .artifact-datasets table{width:100%;border-collapse:collapse;font-size:13px}
        .artifact-datasets thead th{text-align:left;padding:8px 8px;border-bottom:1px solid #e5e7eb;color:#6b7280;font-weight:700;white-space:nowrap}
        .artifact-datasets tbody td{padding:8px 8px;border-bottom:1px solid #e5e7eb;vertical-align:top}
      CSS

      section.add_child(style)

      header = Nokogiri::XML::Node.new("h2", doc)
      header.content = "Data (Edited)"
      section.add_child(header)

      datasets.each_with_index do |ds, idx|
        ds_wrap = Nokogiri::XML::Node.new("div", doc)
        ds_wrap["class"] = "ds"
        ds_wrap["data-dataset-index"] = idx.to_s

        name = safe_string(ds["name"]).presence || "Dataset #{idx + 1}"
        units = safe_string(ds["units"]).presence
        schema = Array(ds["schema"]).map { |s| safe_string(s) }
        rows = Array(ds["rows"]).map { |r| Array(r) }

        h3 = Nokogiri::XML::Node.new("h3", doc)
        h3.content = name
        ds_wrap.add_child(h3)

        if units
          meta = Nokogiri::XML::Node.new("p", doc)
          meta["class"] = "meta"
          meta.content = units
          ds_wrap.add_child(meta)
        end

        table = Nokogiri::XML::Node.new("table", doc)
        table["aria-label"] = name

        thead = Nokogiri::XML::Node.new("thead", doc)
        trh = Nokogiri::XML::Node.new("tr", doc)
        schema.each do |col|
          th = Nokogiri::XML::Node.new("th", doc)
          th.content = col.to_s
          trh.add_child(th)
        end
        thead.add_child(trh)

        tbody = Nokogiri::XML::Node.new("tbody", doc)
        rows.each do |row|
          tr = Nokogiri::XML::Node.new("tr", doc)
          row.each do |cell|
            td = Nokogiri::XML::Node.new("td", doc)
            td.content = format_cell(cell)
            tr.add_child(td)
          end
          tbody.add_child(tr)
        end

        table.add_child(thead)
        table.add_child(tbody)

        ds_wrap.add_child(table)
        section.add_child(ds_wrap)
      end

      body.add_child(section)

      doc.to_html
    rescue => e
      Rails.logger.info("[Ai::ArtifactDatasetTableInjector] failed: #{e.class}: #{e.message}")
      @html
    end

    private

    def extract_datasets(obj)
      h = obj.is_a?(Hash) ? obj : {}
      arr = h["datasets"] || h[:datasets]
      return [] unless arr.is_a?(Array)
      arr.select { |x| x.is_a?(Hash) }
    end

    def safe_string(v)
      v.to_s
    end

    def format_cell(cell)
      return "—" if cell.nil?
      if cell.is_a?(Float) && cell.to_i.to_f == cell
        cell.to_i.to_s
      else
        cell.to_s
      end
    end
  end
end
