require "test_helper"
require "securerandom"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "sign up creates company and owner membership" do
    email = "owner-#{SecureRandom.hex(4)}@example.com"

    assert_difference("User.count", 1) do
      assert_difference("Company.count", 1) do
        assert_difference("Membership.count", 1) do
          post user_registration_path, params: {
            user: {
              company_name: "Acme Labs",
              email: email,
              password: "password123",
              password_confirmation: "password123"
            }
          }
        end
      end
    end

    assert_response :redirect

    user = User.find_by!(email: email)
    membership = user.memberships.includes(:company).first

    assert_not_nil membership
    assert_equal "Acme Labs", membership.company.name
    assert_equal "owner", membership.role
    assert_equal "active", membership.status
  end

  test "sign up with blank company name does not persist records" do
    assert_no_difference("Company.count") do
      assert_no_difference("User.count") do
        assert_no_difference("Membership.count") do
          post user_registration_path, params: {
            user: {
              company_name: "",
              email: "owner-#{SecureRandom.hex(4)}@example.com",
              password: "password123",
              password_confirmation: "password123"
            }
          }
        end
      end
    end

    assert_response :unprocessable_content
  end
end
