Rails.application.routes.draw do
  get "sessions/logout"
  get "sessions/omniauth"
  get "users/show"
  get "welcome/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root 'welcome#index'
  get 'welcome/index', to: 'welcome#index', as: 'welcome'

  get '/users/:id', to: 'users#show', as: 'user'

  get '/logout', to: 'sessions#logout', as: 'logout'
  get '/auth/google_oauth2/callback', to: 'sessions#omniauth'

  post '/workspace/upload', to: 'workspace#upload', as: :workspace_upload
  get '/workspace/download_analysis_report', to: 'workspace#download_analysis_report', as: :workspace_download_analysis_report

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
