# frozen_string_literal: true

# Protected /api/v1/* and /v1/* paths: API key (ENV["API_KEY"]) via X-Api-Key or Authorization Bearer.
# GET is default; POST allowed only for storing JSON (see ALLOWED_POST_SUBPATHS).
# /up is open. Missing API_KEY env → 503.
class ApiKeyMiddleware
  PROTECTED_PREFIXES = [ "/api/v1", "/v1" ].freeze
  ALLOWED_POST_SUFFIX = "/stored_payloads".freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"].to_s
    return @app.call(env) unless protected_path?(path)

    method = env["REQUEST_METHOD"].to_s.upcase

    unless method_allowed?(method, path)
      return json_error(
        env,
        status: 405,
        headers_extra: { "Allow" => allow_header_for(path) },
        code: "METHOD_NOT_ALLOWED",
        message: "HTTP method #{method} is not allowed on this path.",
        hint: method_hint(path)
      )
    end

    expected = api_key_from_env
    unless expected
      return json_error(
        env,
        status: 503,
        code: "API_KEY_NOT_CONFIGURED",
        message: "API_KEY is not set on the server.",
        hint: "Add the Railway variable API_KEY with your secret."
      )
    end

    provided = credential_from_headers(env)
    if provided.blank?
      return json_error(
        env,
        status: 401,
        headers_extra: { "WWW-Authenticate" => %(ApiKey realm="PhoneLib", charset=UTF-8) },
        code: "API_KEY_MISSING",
        message: "Send X-Api-Key or Authorization: Bearer matching the server API_KEY.",
        hint: "Value must equal the API_KEY service variable (e.g. Railway)."
      )
    end

    unless secure_match?(provided, expected)
      return json_error(
        env,
        status: 401,
        headers_extra: { "WWW-Authenticate" => %(ApiKey realm="PhoneLib", charset=UTF-8) },
        code: "API_KEY_INVALID",
        message: "The key does not match API_KEY configured for this deployment.",
        hint: "Check Railway API_KEY and the X-Api-Key header value."
      )
    end

    @app.call(env)
  end

  private

  def method_allowed?(method, path)
    base = strip_query(path)

    return true if method == "GET"

    return true if method == "POST" && post_store_path?(base)

    false
  end

  def post_store_path?(base)
    PROTECTED_PREFIXES.any? { |p| "#{p}#{ALLOWED_POST_SUFFIX}" == base }
  end

  def allow_header_for(path)
    base = strip_query(path)
    if post_store_path?(base)
      "GET, POST"
    else
      "GET"
    end
  end

  def method_hint(path)
    base = strip_query(path)
    if post_store_path?(base)
      "Use GET for retrieval, or POST with JSON to #{base} to store a payload."
    else
      "Use GET /api/v1/phones/random or stored_payloads endpoints. Store JSON with POST /api/v1/stored_payloads only."
    end
  end

  def strip_query(path)
    path.to_s.split("?", 2).first
  end

  def api_key_from_env
    ENV.fetch("API_KEY", "").to_s.strip.presence
  end

  def credential_from_headers(env)
    x = env["HTTP_X_API_KEY"].to_s.strip
    return x if x.present?

    auth = env["HTTP_AUTHORIZATION"].to_s.strip
    m = auth.match(/\ABearer\s+(.+)\z/m)
    m ? m[1].to_s.strip.presence : nil
  end

  def secure_match?(provided, expected)
    return false if provided.blank? || expected.blank?
    return false unless provided.bytesize == expected.bytesize

    ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end

  def protected_path?(path)
    return false if path == "/up"

    PROTECTED_PREFIXES.any? { |p| path == p || path.start_with?("#{p}/") }
  end

  def json_error(env, status:, code:, message:, hint:, headers_extra: {})
    rid = ActionDispatch::Request.new(env).request_id || env["action_dispatch.request_id"]

    body = {
      success: false,
      meta: {
        request_id: rid,
        timestamp: Time.current.iso8601(3)
      },
      error: {
        code: code,
        message: message,
        hint: hint
      }
    }

    json = ActiveSupport::JSON.encode(body)
    headers = Rack::Headers.new.tap do |h|
      h["Content-Type"] = "application/json; charset=UTF-8"
      h["Content-Length"] = json.bytesize.to_s
      headers_extra.each { |k, v| h[k] = v }
    end

    [ status, headers, [ json ] ]
  end
end
