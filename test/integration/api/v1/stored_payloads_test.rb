# frozen_string_literal: true

require "test_helper"

class ApiV1StoredPayloadsTest < ActionDispatch::IntegrationTest
  setup do
    @headers = {
      "X-Api-Key" => ENV.fetch("API_KEY"),
      "Accept" => "application/json"
    }
    StoredPayload.delete_all
  end

  teardown do
    StoredPayload.delete_all
  end

  test "POST stores JSON and returns index; GET returns same payload" do
    payload = { "hello" => [ 1, 2, 3 ], "n" => nil, "b" => false }
    post "/api/v1/stored_payloads",
      params: ActiveSupport::JSON.encode(payload),
      headers: @headers.merge("Content-Type" => "application/json")

    assert_response :success
    idx = response.parsed_body.dig("data", "index")
    assert idx.is_a?(Integer)

    get "/api/v1/stored_payloads/#{idx}", headers: @headers
    assert_response :success
    assert_equal payload.as_json, response.parsed_body.dig("data", "payload")
    assert_equal idx, response.parsed_body.dig("data", "index")
  end

  test "GET latest_index reflects highest id" do
    post "/api/v1/stored_payloads",
      params: '{"a":1}',
      headers: @headers.merge("Content-Type" => "application/json")
    assert_response :success
    i1 = response.parsed_body.dig("data", "index")

    post "/api/v1/stored_payloads",
      params: '{"b":2}',
      headers: @headers.merge("Content-Type" => "application/json")
    i2 = response.parsed_body.dig("data", "index")

    get "/api/v1/stored_payloads/latest_index", headers: @headers
    assert_response :success
    assert_equal [ i1, i2 ].max, response.parsed_body.dig("data", "latest_index")
  end

  test "GET unknown index returns structured 404" do
    get "/api/v1/stored_payloads/99999", headers: @headers
    assert_response :not_found
    assert_equal "NOT_FOUND", response.parsed_body.dig("error", "code")
  end

  test "POST without application/json returns 415" do
    post "/api/v1/stored_payloads",
      params: "not-json",
      headers: @headers.merge("Content-Type" => "text/plain")
    assert_response 415
    assert_equal "UNSUPPORTED_MEDIA_TYPE", response.parsed_body.dig("error", "code")
  end

  test "POST invalid JSON returns 400" do
    post "/api/v1/stored_payloads",
      params: "{",
      headers: @headers.merge("Content-Type" => "application/json")
    assert_response :bad_request
    assert_equal "INVALID_JSON", response.parsed_body.dig("error", "code")
  end

  test "POST without API key returns 401" do
    post "/api/v1/stored_payloads",
      params: "{}",
      headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  test "purge job clears all payloads" do
    post "/api/v1/stored_payloads",
      params: '{"z":true}',
      headers: @headers.merge("Content-Type" => "application/json")
    assert_predicate StoredPayload.count, :positive?

    StoredPayloadPurgeJob.perform_now
    assert_equal 0, StoredPayload.count
  end

  test "/v1 prefix mirrors /api/v1 stored_payloads" do
    post "/v1/stored_payloads",
      params: '{"t":9}',
      headers: @headers.merge("Content-Type" => "application/json")
    assert_response :success
    idx = response.parsed_body.dig("data", "index")

    get "/v1/stored_payloads/#{idx}", headers: @headers
    assert_response :success
  end
end
