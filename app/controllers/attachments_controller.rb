class AttachmentsController < ApplicationController
  before_action :set_attachment, only: %i[ show edit update destroy ]

  # GET /attachments or /attachments.json
  def index
    @attachments = Attachment.all
  end

  # GET /attachments/1 or /attachments/1.json
  def show
  end

  # GET /attachments/new
  def new
    @attachment = Attachment.new
  end

  # GET /attachments/1/edit
  def edit
  end

  # POST /attachments or /attachments.json
  def create
    @attachment = Attachment.new(attachment_params)

    respond_to do |format|
      if @attachment.save
        format.html { redirect_to @attachment, notice: "Attachment was successfully created." }
        format.json { render :show, status: :created, location: @attachment }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @attachment.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /attachments/1 or /attachments/1.json
  def update
    respond_to do |format|
      if @attachment.update(attachment_params)
        format.html { redirect_to @attachment, notice: "Attachment was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @attachment }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @attachment.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /attachments/1 or /attachments/1.json
  def destroy
    @attachment.destroy!

    respond_to do |format|
      format.html { redirect_to attachments_path, notice: "Attachment was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_attachment
      @attachment = Attachment.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def attachment_params
      params.require(:attachment).permit(:company_id, :created_by_id, :attachable_id, :attachable_type, :kind, :title, :body, :metadata, :status)
    end
end
