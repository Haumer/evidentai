# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  # ---- Core app ----
  resources :chats, only: [:index, :show, :create, :update, :destroy] do
    resources :user_messages, only: [:create]
    member do
      get :artifact_preview
      get :edit_title
      get :sidebar_title
      patch :update_title
      patch :toggle_context_suggestions
    end
  end

  # ---- Read-only AI outputs ----
  resources :ai_messages, only: [:show]

  # NOTE: Artifacts are "read-only" as a resource, but we allow dataset cell edits
  # via nested routes (Turbo Frames) to support user-owned dataset corrections.
  resources :artifacts, only: [:index, :show] do
    scope module: :artifacts do
      resources :triggers, only: [:create, :destroy] do
        post :fire, on: :member
      end

      resources :datasets, only: [] do
        # Show a cell in non-editing mode (used for Cancel)
        # /artifacts/:artifact_id/datasets/:dataset_id/cell/:row_index/:col_index
        get  "cell/:row_index/:col_index",          to: "cells#show",  as: :cell_show

        # Edit a cell (renders the inline form inside the Turbo Frame)
        # /artifacts/:artifact_id/datasets/:dataset_id/cell/edit/:row_index/:col_index
        get  "cell/edit/:row_index/:col_index",     to: "cells#edit",  as: :cell_edit

        # Update a cell
        # /artifacts/:artifact_id/datasets/:dataset_id/cell/:row_index/:col_index
        patch "cell/:row_index/:col_index",         to: "cells#update", as: :cell_update
      end
    end
  end

  namespace :api do
    resources :artifact_triggers, only: [] do
      post :fire, on: :member
    end
  end

  # ---- Supporting ----
  resources :attachments, only: [:create, :destroy]
  resources :users, only: [:show, :update] do
    member do
      patch :reactivate_suggestions
    end
  end
  resources :memberships
  resources :companies

  namespace :admin do
    get :ai_usage, to: "ai_usage#index"
    post "ai_usage/retry_run", to: "ai_usage#retry_run", as: :ai_usage_retry_run
  end

  # ---- System ----
  get "/setup", to: "pages#setup", as: :setup
  get "up" => "rails/health#show", as: :rails_health_check

  root to: "chats#index"
end
