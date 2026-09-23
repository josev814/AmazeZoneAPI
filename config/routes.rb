Rails.application.routes.draw do
  get "healthz", to: "rails/health#show", as: :rails_health_check

  post '/auth/login', to: 'auth#login'

  get '/auth/current', to: 'auth#current'

  post '/signup', to: 'users#create'

  resources :products

end
