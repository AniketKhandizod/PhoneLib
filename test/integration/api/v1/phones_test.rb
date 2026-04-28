# frozen_string_literal: true

require "test_helper"

class ApiV1PhonesTest < ActionDispatch::IntegrationTest
  def data(payload)
    payload["data"] || payload
  end

  test "disallowed client IP receives 403 with reason" do
    get "/api/v1/phones/random", env: { "REMOTE_ADDR" => "203.0.113.99" }
    assert_response :forbidden
    body = response.parsed_body
    assert_equal "FORBIDDEN_CLIENT_IP", body.dig("error", "code")
    assert_match "203.0.113.99", body.dig("error", "message").to_s
    assert_match "127.0.0.1", body.dig("error", "message").to_s
  end

  test "/health up is not IP-gated or method-filtered by API middleware" do
    get "/up"
    assert_includes [ 200, 500 ], response.status
  end

  test "POST returns 405 with descriptive JSON" do
    post "/api/v1/phones/random"
    assert_response 405
    body = response.parsed_body
    assert_equal "METHOD_NOT_ALLOWED", body.dig("error", "code")
    assert_match "POST", body.dig("error", "message").to_s
  end

  test "random GET returns phone_number country_code country_name via phonelib" do
    get "/api/v1/phones/random"
    assert_response :success
    j = response.parsed_body
    d = data(j)
    assert d["phone_number"].to_s.start_with?("+"), -> { response.body }
    assert_match(/\A\d+\z/, d["country_code"].to_s)
    assert d["country_name"].present?
    assert_nil d["short_country_name"]
    assert_equal true, j["success"]
  end

  test "/v1 shortcut equals /api/v1 behaviour" do
    get "/v1/phones/random"
    assert_response :success
    d = response.parsed_body["data"]
    assert d["phone_number"].to_s.start_with?("+")
    assert d["country_code"].present?
    assert d["country_name"].present?
  end

  test "unknown GET path returns structured 404" do
    get "/api/v1/phones/randon"
    assert_response :not_found
    body = response.parsed_body
    assert_equal "ROUTE_NOT_FOUND", body.dig("error", "code")
    assert_equal "/api/v1/phones/randon", body.dig("error", "details").first["path"]
  end
end
