Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"
  resources :scans, only: :create
  resources :library, only: :index
  resources :covers, only: :show
  resources :missing_media_files, only: :index
  resources :unidentified_media_files, only: :index
  resources :media_file_identifications, only: :update
  resources :wishlist_items, only: [:index, :create, :update, :destroy]
  resources :wishlist_searches, only: :index
end
