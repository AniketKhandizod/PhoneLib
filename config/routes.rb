Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  concern :api_v1_phone_routes do
    get "phones/random", to: "phones#random"
  end

  concern :api_v1_stored_payload_routes do
    post "stored_payloads", to: "stored_payloads#create"
    get "stored_payloads/latest_index", to: "stored_payloads#latest_index"
    get "stored_payloads/:index", to: "stored_payloads#show", constraints: { index: /\d+/ }
  end

  concern :api_v1_fallback do
    match "*path", to: "routing#not_found", via: :get
  end

  namespace :api do
    namespace :v1 do
      concerns :api_v1_phone_routes
      concerns :api_v1_stored_payload_routes
      concerns :api_v1_fallback
    end
  end

  scope "/v1", module: "api/v1", as: "plain_v1" do
    concerns :api_v1_phone_routes
    concerns :api_v1_stored_payload_routes
    concerns :api_v1_fallback
  end
end
