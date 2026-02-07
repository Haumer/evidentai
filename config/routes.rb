# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users

  # ---- Core app ----
  resources :chats, only: [:index, :show, :create, :update, :destroy] do
    resources :user_messages, only: [:create]
  end

  # ---- Read-only AI outputs ----
  resources :ai_messages, only: [:show]
  resources :artifacts, only: [:show]

  # ---- Supporting ----
  resources :attachments, only: [:create, :destroy]
  resources :memberships
  resources :companies

  # ---- System ----
  get "/setup", to: "pages#setup", as: :setup
  get "up" => "rails/health#show", as: :rails_health_check

  root to: "chats#index"
end
