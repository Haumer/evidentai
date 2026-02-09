class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  has_many :memberships, dependent: :destroy
  has_many :companies, through: :memberships

  def context_suggestions_enabled?
    return true unless has_attribute?(:context_suggestions_enabled)

    self[:context_suggestions_enabled] != false
  end
end
