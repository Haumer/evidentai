class Artifacts::TriggersController < ApplicationController
  before_action :ensure_membership!
  before_action :set_artifact
  before_action :set_trigger, only: %i[fire destroy]

  def create
    trigger = @artifact.artifact_triggers.new(trigger_params)
    trigger.company = @company
    trigger.chat = @artifact.chat
    trigger.created_by = current_user

    if trigger.save
      redirect_to artifact_path(@artifact), notice: "Trigger created."
    else
      redirect_to artifact_path(@artifact), alert: trigger.errors.full_messages.join(", ")
    end
  end

  def fire
    @trigger.enqueue_run!(
      input_text: params[:input_text],
      context_turns: params[:context_turns],
      context_max_chars: params[:context_max_chars],
      fired_by: current_user,
      source: "manual"
    )

    redirect_to artifact_path(@artifact), notice: "Trigger queued."
  rescue => e
    redirect_to artifact_path(@artifact), alert: e.message
  end

  def destroy
    @trigger.destroy!
    redirect_to artifact_path(@artifact), notice: "Trigger removed."
  end

  private

  def ensure_membership!
    membership = current_user.memberships.first
    redirect_to setup_path and return unless membership
    @company = membership.company
  end

  def set_artifact
    @artifact = Artifact.where(company: @company).find(params[:artifact_id])
  end

  def set_trigger
    @trigger = @artifact.artifact_triggers.find(params[:id])
  end

  def trigger_params
    params.require(:artifact_trigger).permit(
      :name,
      :trigger_type,
      :status,
      :instruction_template,
      :context_turns,
      :context_max_chars
    )
  end
end
