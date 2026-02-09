class Api::ArtifactTriggersController < ApplicationController
  skip_before_action :authenticate_user!
  skip_forgery_protection

  def fire
    trigger = ArtifactTrigger.find(params[:id])
    provided_token = bearer_token || params[:token].to_s

    unless valid_token?(provided_token, trigger.api_token.to_s)
      render json: { error: "unauthorized" }, status: :unauthorized and return
    end

    user_message = trigger.enqueue_run!(
      input_text: params[:input_text].to_s,
      context_turns: params[:context_turns],
      context_max_chars: params[:context_max_chars],
      fired_by: trigger.created_by,
      source: "api"
    )

    render json: {
      queued: true,
      user_message_id: user_message.id,
      artifact_id: trigger.artifact_id,
      chat_id: trigger.chat_id
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "not_found" }, status: :not_found
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def bearer_token
    header = request.headers["Authorization"].to_s
    return "" if header.blank?

    parts = header.split(" ", 2)
    return "" unless parts.length == 2
    return "" unless parts.first.casecmp("bearer").zero?

    parts.last.to_s
  end

  def valid_token?(provided, expected)
    return false if provided.blank? || expected.blank?
    return false unless provided.bytesize == expected.bytesize

    ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end
end
