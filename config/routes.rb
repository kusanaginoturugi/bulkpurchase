# frozen_string_literal: true

Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :passwords, only: %i[new create edit update], param: :token
  resource :current_order, only: %i[show create update], controller: :current_orders
  resources :orders, only: %i[index show]
  resources :items, only: [] do
    collection do
      get :search
    end
  end

  namespace :admin do
    root "order_cycles#index"

    resources :organizations, only: %i[index create edit update destroy]
    resources :users, only: %i[index create edit update destroy]
    resources :items, only: %i[index create edit update]
    resources :order_cycles, only: %i[index show create edit update]
    resources :orders, only: %i[index show edit update destroy]
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "current_orders#show"
end
