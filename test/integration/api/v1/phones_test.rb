# frozen_string_literal: true

require "test_helper"

class ApiV1PhonesTest < ActionDispatch::IntegrationTest
  def data(payload)
    payload["data"] || payload
  end

  test "disallowed client IP receives 403 with reason" do
    # test_helper sets ALLOWED_CLIENT_IP=127.0.0.1; simulate a different client via REMOTE_ADDR.
    get "/api/v1/phones/random", env: { "REMOTE_ADDR" => "203.0.113.99" }
    assert_response :forbidden
    body = response.parsed_body
    assert_equal "FORBIDDEN_CLIENT_IP", body.dig("error", "code")
    assert_match "203.0.113.99", body.dig("error", "message").to_s
    assert_match "127.0.0.1", body.dig("error", "message").to_s
  end

  test "/health up is not IP-gated" do
    get "/up"
    assert_includes [ 200, 500 ], response.status
  end

  test "random phone returns e164 and fields" do
    get "/api/v1/phones/random"
    assert_response :success
    j = response.parsed_body
    d = data(j)
    assert d["phone"].to_s.start_with?("+"), -> { response.body }
    assert d["country_code"].present?
    assert d["country_name"].present?
    assert d["short_country_name"].to_s.length == 2
    assert_equal true, j["success"]
  end

  test "/v1 shortcut prefix matches canonical /api/v1 behaviour" do
    get "/v1/phones/random"
    assert_response :success
    assert response.parsed_body.dig("data", "phone").to_s.start_with?("+"),
      "expected #{response.parsed_body.inspect}"
  end

  test "lookup for US" do
    get "/api/v1/phones/lookup?phone=2015550123&country=US"
    assert_response :success
    j = response.parsed_body
    d = data(j)
    assert_equal "US", d["short_country_name"]
  end

  test "validate india mobile" do
    post "/api/v1/phones/validate",
      params: { phone: "8123456789", country_code: "91" }.to_json,
      headers: { "Content-Type" => "application/json" }
    assert_response :success
    j = response.parsed_body
    d = data(j)
    assert_equal true, d["valid"]
  end

  test "unknown nested path returns structured 404 without auth header" do
    get "/api/v1/phones/randon"
    assert_response :not_found
    body = response.parsed_body
    assert_equal "ROUTE_NOT_FOUND", body.dig("error", "code")
    detail = body.dig("error", "details").first
    assert_equal "/api/v1/phones/randon", detail["path"]
  end

  test "malformed JSON for validate returns INVALID_JSON" do
    post "/api/v1/phones/validate",
      params: "{",
      headers: { "Content-Type" => "application/json" }
    assert_response :bad_request
    assert_equal "INVALID_JSON", response.parsed_body.dig("error", "code")
  end
end
