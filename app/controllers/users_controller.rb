class UsersController < ApplicationController
  before_action :set_user

  def show
    @company = current_user.memberships.includes(:company).first&.company
    @chats = @company ? Chat.where(company: @company).order(updated_at: :desc) : []
  end

  def update
    @user.update!(user_params)
    redirect_to user_path(@user), notice: "Settings updated."
  end

  def reactivate_suggestions
    company_ids = current_user.memberships.select(:company_id)

    @user.update!(context_suggestions_enabled: true)
    Chat.where(company_id: company_ids).update_all(context_suggestions_enabled: true)

    redirect_to user_path(@user), notice: "Suggestions re-activated for all chats."
  end

  private

  def set_user
    @user = User.find(params[:id])
    return if @user == current_user

    redirect_to(user_path(current_user), alert: "You can only edit your own profile.") and return
  end

  def user_params
    params.require(:user).permit(:context_suggestions_enabled)
  end
end
