# frozen_string_literal: true

require "test_helper"

class ApiV1PhonesTest < ActionDispatch::IntegrationTest
  setup do
    @headers = { "Authorization" => "Bearer test-bearer" }
  end

  test "random phone returns 401 without token" do
    get "/api/v1/phones/random"
    assert_response :unauthorized
  end

  test "random phone returns e164 and fields" do
    get "/api/v1/phones/random", headers: @headers
    assert_response :success
    j = response.parsed_body
    assert j["phone"].to_s.start_with?("+")
    assert j["country_code"].present?
    assert j["country_name"].present?
    assert j["short_country_name"].to_s.length == 2
  end

  test "lookup for US" do
    get "/api/v1/phones/lookup?phone=2015550123&country=US", headers: @headers
    assert_response :success
    j = response.parsed_body
    assert_equal "US", j["short_country_name"]
  end

  test "validate india mobile" do
    post "/api/v1/phones/validate",
      params: { phone: "8123456789", country_code: "91" }.to_json,
      headers: @headers.merge("Content-Type" => "application/json")
    assert_response :success
    j = response.parsed_body
    assert j["valid"] == true
  end
end
