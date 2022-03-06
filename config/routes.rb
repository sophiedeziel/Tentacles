Rails.application.routes.draw do
  resources :printers
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "react#index"
end
