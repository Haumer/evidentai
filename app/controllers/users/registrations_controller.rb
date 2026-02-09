module Users
  class RegistrationsController < Devise::RegistrationsController
    def create
      permitted = sign_up_params
      company_name = permitted.delete(:company_name).to_s.strip

      build_resource(permitted)
      resource.company_name = company_name
      validate_signup(company_name)

      if resource.errors.any?
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource and return
      end

      ActiveRecord::Base.transaction do
        company = Company.create!(name: company_name, status: "active")
        resource.save!
        Membership.create!(user: resource, company: company, role: "owner", status: "active")
      end

      yield resource if block_given?

      if resource.persisted?
        if resource.active_for_authentication?
          set_flash_message! :notice, :signed_up
          sign_up(resource_name, resource)
          respond_with resource, location: after_sign_up_path_for(resource)
        else
          set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
          expire_data_after_sign_in!
          respond_with resource, location: after_inactive_sign_up_path_for(resource)
        end
      else
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource
      end
    rescue ActiveRecord::RecordInvalid => error
      attach_transaction_error(error)
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end

    protected

    def sign_up_params
      params.require(resource_name).permit(:email, :password, :password_confirmation, :company_name)
    end

    private

    def validate_signup(company_name)
      resource.validate
      resource.errors.add(:company_name, "can't be blank") if company_name.blank?
    end

    def attach_transaction_error(error)
      return if resource.blank?
      return unless error.record.is_a?(Company) || error.record.is_a?(Membership)

      message = error.record.errors.full_messages.to_sentence
      message = "Sign up failed. Please try again." if message.blank?
      resource.errors.add(:base, message)
    end
  end
end
