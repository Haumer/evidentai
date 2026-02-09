class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  attr_accessor :company_name

  has_many :memberships, dependent: :destroy
  has_many :companies, through: :memberships
  has_many :artifact_triggers, foreign_key: :created_by_id, dependent: :destroy

  def display_name
    email.to_s.split("@").first.to_s.strip.presence || email.to_s
  end

  def context_suggestions_enabled?
    return true unless has_attribute?(:context_suggestions_enabled)

    self[:context_suggestions_enabled] != false
  end
end
