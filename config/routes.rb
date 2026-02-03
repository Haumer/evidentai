Rails.application.routes.draw do
  resources :conversations
  resources :outputs
  resources :attachments
  resources :prompts
  resources :memberships
  resources :companies
  devise_for :users
  root to: "pages#home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  resources :companies do
    resources :memberships, shallow: true
  end

  resources :prompts do
    resources :attachments
    resources :outputs
  end
  resources :conversations do
    resources :prompts, only: [:create]
  end

  resources :prompts, only: [:show] do
    post :submit, on: :member
    get :status, on: :member
  end

  get "/setup", to: "pages#setup", as: :setup
end
