Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Shared v1 phone endpoints (canonical prefix: /api/v1/...). Also exposed at /v1/... for clients that omit /api.
  concern :api_v1_phone_routes do
    get "phones/random", to: "phones#random"
    get "phones/lookup", to: "phones#lookup"
    post "phones/validate", to: "phones#validate"
    match "*path", to: "routing#not_found", via: :all
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
