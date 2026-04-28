# frozen_string_literal: true

require "test_helper"

class ApiV1PhonesTest < ActionDispatch::IntegrationTest
  setup do
    @key_headers = {
      "X-Api-Key" => ENV.fetch("API_KEY", "XYZ789rk@@@"),
      "Accept" => "application/json"
    }
  end

  def data(payload)
    payload["data"] || payload
  end

  test "missing API key returns 401 with reason" do
    get "/api/v1/phones/random"
    assert_response :unauthorized
    body = response.parsed_body
    assert_equal "API_KEY_MISSING", body.dig("error", "code")
    assert_predicate body.dig("error", "hint"), :present?
  end

  test "wrong API key returns 401" do
    get "/api/v1/phones/random", headers: @key_headers.merge("X-Api-Key" => "not-valid")
    assert_response :unauthorized
    assert_equal "API_KEY_INVALID", response.parsed_body.dig("error", "code")
  end

  test "Authorization Bearer is accepted instead of X-Api-Key" do
    token = ENV.fetch("API_KEY")
    get "/api/v1/phones/random",
      headers: { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
    assert_response :success
    assert_predicate response.parsed_body.dig("data", "phone_number"), :present?
  end

  test "/health up is not gated by API key" do
    get "/up"
    assert_includes [ 200, 500 ], response.status
  end

  test "POST returns 405 before API key semantics" do
    post "/api/v1/phones/random"
    assert_response 405
    body = response.parsed_body
    assert_equal "METHOD_NOT_ALLOWED", body.dig("error", "code")
    assert_match "POST", body.dig("error", "message").to_s
  end

  test "random GET with X-Api-Key returns phone fields" do
    get "/api/v1/phones/random", headers: @key_headers
    assert_response :success
    j = response.parsed_body
    d = data(j)
    assert d["phone_number"].to_s.start_with?("+"), -> { response.body }
    assert_match(/\A\d+\z/, d["country_code"].to_s)
    assert d["country_name"].present?
    assert_nil d["short_country_name"]
    assert_equal true, j["success"]
  end

  test "/v1 shortcut with API key succeeds" do
    get "/v1/phones/random", headers: @key_headers
    assert_response :success
    d = response.parsed_body["data"]
    assert d["phone_number"].to_s.start_with?("+")
    assert d["country_code"].present?
    assert d["country_name"].present?
  end

  test "unknown GET path returns structured 404 when key OK" do
    get "/api/v1/phones/randon", headers: @key_headers
    assert_response :not_found
    body = response.parsed_body
    assert_equal "ROUTE_NOT_FOUND", body.dig("error", "code")
    assert_equal "/api/v1/phones/randon", body.dig("error", "details").first["path"]
  end
end
