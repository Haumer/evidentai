# app/services/ai/artifacts/dataset/computed_cells.rb
#
# Applies row-level computed column formulas stored in dataset_json.
# This is intentionally server-side and deterministic (no eval, no JS).
#
# Supported metadata per dataset:
#   "computed_columns": [
#     { "index": 2, "formula": "A - B" }
#   ]
#
# Notes:
# - Column refs use spreadsheet letters (A, B, ... AA).
# - Formulas support +, -, *, /, parentheses, unary minus, and decimal literals.
# - If a referenced cell is blank/non-numeric or divide-by-zero occurs, computed value becomes nil.

module Ai
  module Artifacts
    module Dataset
      class ComputedCells
        class ParseError < StandardError; end
        class NonNumericReference < StandardError; end

        def self.apply(dataset_json)
          new(dataset_json).call
        end

        def self.computed_column_indexes(dataset)
          schema_size = Array(read_key(dataset, "schema")).size
          normalized_computed_columns(dataset, schema_size).map { |c| c[:index] }.uniq
        end

        def initialize(dataset_json)
          @dataset_json = dataset_json
        end

        def call
          return @dataset_json unless @dataset_json.is_a?(Hash)

          duplicated = JSON.parse(@dataset_json.to_json)
          datasets = read_key(duplicated, "datasets")
          return duplicated unless datasets.is_a?(Array)

          datasets.each do |dataset|
            next unless dataset.is_a?(Hash)

            apply_dataset!(dataset)
          end

          duplicated
        rescue => e
          Rails.logger.info("[Ai::Artifacts::Dataset::ComputedCells] failed: #{e.class}: #{e.message}")
          @dataset_json
        end

        private

        def apply_dataset!(dataset)
          rows = read_key(dataset, "rows")
          schema = read_key(dataset, "schema")
          return unless rows.is_a?(Array) && schema.is_a?(Array)

          computed_columns = self.class.send(:normalized_computed_columns, dataset, schema.size)
          return if computed_columns.empty?

          rows.each do |row|
            next unless row.is_a?(Array)

            computed_columns.each do |computed|
              row[computed[:index]] = evaluate_formula_for_row(computed[:formula], row)
            rescue ParseError, NonNumericReference
              row[computed[:index]] = nil
            end
          end
        end

        def evaluate_formula_for_row(formula, row)
          @tokens = tokenize(formula.to_s)
          @token_index = 0
          @row = row

          value = parse_expression
          raise ParseError, "Unexpected token" unless current_token.nil?

          normalize_numeric(value)
        ensure
          @tokens = nil
          @token_index = nil
          @row = nil
        end

        def tokenize(formula)
          tokens = []
          i = 0

          while i < formula.length
            ch = formula[i]

            if ch.match?(/\s/)
              i += 1
              next
            end

            if ch.match?(/[0-9.]/)
              j = i + 1
              j += 1 while j < formula.length && formula[j].match?(/[0-9.]/)
              literal = formula[i...j]
              raise ParseError, "Invalid number" unless literal.match?(/\A\d+(?:\.\d+)?\z/)

              tokens << [:number, literal.to_f]
              i = j
              next
            end

            if ch.match?(/[A-Za-z]/)
              j = i + 1
              j += 1 while j < formula.length && formula[j].match?(/[A-Za-z]/)
              tokens << [:ref, formula[i...j].upcase]
              i = j
              next
            end

            if %w[+ - * / ( )].include?(ch)
              tokens << [ch, ch]
              i += 1
              next
            end

            raise ParseError, "Invalid token"
          end

          tokens
        end

        def parse_expression
          value = parse_term
          while current_type == "+" || current_type == "-"
            op = current_type
            advance_token
            rhs = parse_term
            value = op == "+" ? value + rhs : value - rhs
          end
          value
        end

        def parse_term
          value = parse_factor
          while current_type == "*" || current_type == "/"
            op = current_type
            advance_token
            rhs = parse_factor

            if op == "*"
              value *= rhs
            else
              raise ParseError, "Divide by zero" if rhs.zero?

              value /= rhs
            end
          end
          value
        end

        def parse_factor
          if current_type == "-"
            advance_token
            return -parse_factor
          end

          if current_type == "("
            advance_token
            value = parse_expression
            raise ParseError, "Missing ')'" unless current_type == ")"

            advance_token
            return value
          end

          if current_type == :number
            value = current_token[1]
            advance_token
            return value
          end

          if current_type == :ref
            ref = current_token[1]
            advance_token
            return reference_value(ref)
          end

          raise ParseError, "Expected value"
        end

        def reference_value(ref)
          index = letters_to_index(ref)
          raw = @row[index]
          num = coerce_numeric(raw)
          raise NonNumericReference, "Non-numeric reference" if num.nil?

          num
        end

        def coerce_numeric(value)
          return value.to_f if value.is_a?(Numeric)

          str = value.to_s.strip
          return nil if str.blank?
          return str.to_f if str.match?(/\A-?\d+(?:\.\d+)?\z/)

          nil
        end

        def normalize_numeric(value)
          return nil unless value.is_a?(Numeric) && value.finite?

          int = value.to_i
          return int if (value - int).abs < 1e-9

          value.round(6)
        end

        def current_token
          @tokens[@token_index]
        end

        def current_type
          current_token&.first
        end

        def advance_token
          @token_index += 1
        end

        def letters_to_index(token)
          value = 0
          token.each_char do |char|
            raise ParseError, "Invalid ref" unless char.match?(/[A-Z]/)

            value = (value * 26) + (char.ord - "A".ord + 1)
          end
          value - 1
        end

        class << self
          private

          def normalized_computed_columns(dataset, schema_size)
            raw_columns = read_key(dataset, "computed_columns")
            return [] unless raw_columns.is_a?(Array) && schema_size.positive?

            seen = {}

            raw_columns.filter_map do |entry|
              next unless entry.is_a?(Hash)

              formula = read_key(entry, "formula").to_s.strip
              next if formula.blank?

              index = parse_index(read_key(entry, "index"))
              index = parse_index(read_key(entry, "column")) if index.nil?
              next unless index.is_a?(Integer)
              next if index.negative? || index >= schema_size
              next if seen[index]

              seen[index] = true
              { index: index, formula: formula }
            end
          end

          def parse_index(raw)
            return raw if raw.is_a?(Integer)
            return nil if raw.nil?

            str = raw.to_s.strip
            return nil if str.blank?

            return str.to_i if str.match?(/\A\d+\z/)

            return letters_to_index(str.upcase) if str.match?(/\A[A-Za-z]+\z/)

            nil
          rescue ParseError
            nil
          end

          def letters_to_index(token)
            value = 0
            token.each_char do |char|
              raise ParseError, "Invalid ref" unless char.match?(/[A-Z]/)

              value = (value * 26) + (char.ord - "A".ord + 1)
            end
            value - 1
          end

          def read_key(hash_like, key)
            return nil unless hash_like.respond_to?(:[])

            hash_like[key] || hash_like[key.to_sym]
          end
        end

        def read_key(hash_like, key)
          return nil unless hash_like.respond_to?(:[])

          hash_like[key] || hash_like[key.to_sym]
        end
      end
    end
  end
end
