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

  def show
    @chats = Chat.where(company: @company).order(updated_at: :desc)
    @artifact = Artifact.where(company: @company).includes(:chat).find(params[:id])
    @chat = @artifact.chat
    @artifact_text = artifact_text_for(@artifact)
    @triggers = @artifact.artifact_triggers.order(created_at: :desc)
    @trigger = @artifact.artifact_triggers.new(
      company: @company,
      created_by: current_user,
      chat: @chat,
      trigger_type: "manual",
      status: "active",
      name: default_trigger_name,
      context_turns: 6,
      context_max_chars: 6000
    )
  end

  private

  def ensure_membership!
    membership = current_user.memberships.first
    unless membership
      redirect_to setup_path and return
    end

    @company = membership.company
  end

  def artifact_text_for(artifact)
    return "" unless artifact

    if artifact.respond_to?(:content) && artifact.content.present?
      artifact.content.is_a?(Hash) ? artifact.content["text"].to_s : artifact.content.to_s
    elsif artifact.respond_to?(:data) && artifact.data.present?
      artifact.data.is_a?(Hash) ? artifact.data["text"].to_s : artifact.data.to_s
    elsif artifact.respond_to?(:body) && artifact.body.present?
      artifact.body.to_s
    elsif artifact.respond_to?(:text) && artifact.text.present?
      artifact.text.to_s
    else
      ""
    end
  end

  def default_trigger_name
    "Run #{Time.current.strftime('%H:%M')}"
  end
end
