Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # GET-only: random Phonelib-valid phone for a random country. Also at /v1/... if /api is omitted.
  concern :api_v1_phone_routes do
    get "phones/random", to: "phones#random"
    match "*path", to: "routing#not_found", via: :get
  end

  namespace :api do
    namespace :v1 do
      concerns :api_v1_phone_routes
    end
  end

  scope "/v1", module: "api/v1", as: "plain_v1" do
    concerns :api_v1_phone_routes
  end
end
