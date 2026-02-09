class Company < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :chats, dependent: :destroy
  has_many :data_source_caches, class_name: "DataSourceCache", dependent: :destroy
  has_many :ai_request_usages, dependent: :destroy
end
