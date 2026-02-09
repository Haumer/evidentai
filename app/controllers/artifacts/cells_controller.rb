# app/controllers/artifacts/cells_controller.rb
module Artifacts
  class CellsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_artifact
    before_action :set_indices

    def show
      render partial: "chats/artifact_sheets/cell", locals: cell_locals(editing: false)
    end

    def edit
      render partial: "chats/artifact_sheets/cell", locals: cell_locals(editing: true)
    end

    def update
      @artifact.update_dataset_cell!(
        dataset_index: @dataset_index,
        row_index: @row_index,
        col_index: @col_index,
        value: params.require(:cell).fetch(:value, "")
      )

      html = Ai::Artifacts::Dataset::ApplyToHtml.call(
        html: @artifact.content,
        dataset_json: @artifact.dataset_json
      )

      @artifact.update!(content: html)

      render turbo_stream: [
        turbo_stream.replace(
          cell_frame_id,
          partial: "chats/artifact_sheets/cell",
          locals: cell_locals(editing: false)
        ),
        turbo_stream.replace(
          "artifact_iframe",
          partial: "chats/artifact_iframe",
          locals: { artifact: @artifact, text: Ai::Artifacts::Dataset::Strip.call(@artifact.content) }
        )
      ]
    rescue ArgumentError => e
      render partial: "chats/artifact_sheets/cell",
             locals: cell_locals(editing: true, error: e.message),
             status: :unprocessable_entity
    end

    private

    def set_artifact
      company_ids = current_user.memberships.select(:company_id)
      @artifact = Artifact.where(company_id: company_ids).find(params[:artifact_id])
    end

    def set_indices
      @dataset_index = params[:dataset_id].to_i
      @row_index = params[:row_index].to_i
      @col_index = params[:col_index].to_i
    end

    def cell_frame_id
      "dataset_cell_#{@dataset_index}_#{@row_index}_#{@col_index}"
    end

    def cell_locals(editing:, error: nil)
      dataset = @artifact.dataset_at(@dataset_index) || {}
      rows = dataset["rows"] || []
      value = rows.dig(@row_index, @col_index)
      computed = @artifact.computed_cell?(dataset_index: @dataset_index, col_index: @col_index)

      {
        artifact: @artifact,
        dataset_index: @dataset_index,
        row_index: @row_index,
        col_index: @col_index,
        value: value,
        computed: computed,
        editing: editing,
        error: error
      }
    end
  end
end
