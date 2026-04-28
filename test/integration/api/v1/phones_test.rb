# frozen_string_literal: true

require "test_helper"

class ApiV1PhonesTest < ActionDispatch::IntegrationTest
  setup do
    @headers = { "Authorization" => "Bearer test-bearer" }
  end

  def data(payload)
    payload["data"] || payload
  end

  test "random phone returns 401 without token" do
    get "/api/v1/phones/random"
    assert_response :unauthorized
    body = response.parsed_body
    assert_equal "AUTHORIZATION_MISSING", body.dig("error", "code")
    assert_predicate body["meta"]["request_id"], :present?
  end

  test "wrong bearer token returns TOKEN_MISMATCH-shaped error" do
    get "/api/v1/phones/random", headers: { "Authorization" => "Bearer definitely-wrong-token" }
    assert_response :unauthorized
    body = response.parsed_body
    assert_equal "BEARER_TOKEN_MISMATCH", body.dig("error", "code")
    assert_predicate body.dig("error", "hint"), :present?
  end

  test "/v1 shortcut prefix matches canonical /api/v1 behaviour" do
    get "/v1/phones/random", headers: @headers
    assert_response :success
    assert response.parsed_body.dig("data", "phone").to_s.start_with?("+"),
      "expected #{response.parsed_body.inspect}"
  end

  test "random phone returns e164 and fields" do
    get "/api/v1/phones/random", headers: @headers
    assert_response :success
    j = response.parsed_body
    d = data(j)
    assert d["phone"].to_s.start_with?("+"), -> { response.body }
    assert d["country_code"].present?
    assert d["country_name"].present?
    assert d["short_country_name"].to_s.length == 2
    assert_equal true, j["success"]
  end

  test "lookup for US" do
    get "/api/v1/phones/lookup?phone=2015550123&country=US", headers: @headers
    assert_response :success
    j = response.parsed_body
    d = data(j)
    assert_equal "US", d["short_country_name"]
  end

  test "validate india mobile" do
    post "/api/v1/phones/validate",
      params: { phone: "8123456789", country_code: "91" }.to_json,
      headers: @headers.merge("Content-Type" => "application/json")
    assert_response :success
    j = response.parsed_body
    d = data(j)
    assert_equal true, d["valid"]
  end

  test "unknown nested path returns structured 404 without auth" do
    get "/api/v1/phones/randon"
    assert_response :not_found
    body = response.parsed_body
    assert_equal "ROUTE_NOT_FOUND", body.dig("error", "code")
    detail = body.dig("error", "details").first
    assert_equal "/api/v1/phones/randon", detail["path"]
  end

  test "malformed JSON for validate returns INVALID_JSON when auth present" do
    post "/api/v1/phones/validate",
      params: "{",
      headers: @headers.merge("Content-Type" => "application/json")
    assert_response :bad_request
    assert_equal "INVALID_JSON", response.parsed_body.dig("error", "code")
  end
end
