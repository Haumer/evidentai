require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @company = Company.create!(name: "Acme", status: "active")
    @user = User.create!(email: "owner@example.com", password: "password123", password_confirmation: "password123")
    Membership.create!(user: @user, company: @company, role: "owner", status: "active")

    @other_user = User.create!(email: "other@example.com", password: "password123", password_confirmation: "password123")
    Membership.create!(user: @other_user, company: @company, role: "member", status: "active")
  end

  test "shows current user profile" do
    sign_in @user

    get user_path(@user)

    assert_response :success
  end

  test "updates current user settings" do
    sign_in @user

    patch user_path(@user), params: { user: { context_suggestions_enabled: "0" } }

    assert_redirected_to user_path(@user)
    assert_equal false, @user.reload.context_suggestions_enabled
  end

  test "redirects when trying to view another user profile" do
    sign_in @user

    get user_path(@other_user)

    assert_redirected_to user_path(@user)
  end
end
