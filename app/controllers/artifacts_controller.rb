class ArtifactsController < ApplicationController
  before_action :ensure_membership!

  def index
    @chats = Chat.where(company: @company).order(updated_at: :desc)

    latest_artifact_ids = Artifact
      .where(company: @company)
      .select("DISTINCT ON (chat_id) id")
      .order("chat_id, created_at DESC, id DESC")

    @artifacts = Artifact
      .where(id: latest_artifact_ids)
      .includes(:chat)
      .order(created_at: :desc)
  end

  # Keep /artifacts/:id available, but send users to the owning chat.
  def show
    artifact = Artifact.where(company: @company).find(params[:id])
    redirect_to chat_path(artifact.chat)
  end

  private

  def ensure_membership!
    membership = current_user.memberships.first
    unless membership
      redirect_to setup_path and return
    end

    @company = membership.company
  end
end
