# frozen_string_literal: true

# GET-only on /api/v1/* and /v1/*. The expected key is ENV["API_KEY"] only (Railway / host env). No default in code.
# Client: X-Api-Key or Authorization: Bearer (same value). /up is unrestricted. Missing API_KEY env → 503.
class ApiKeyMiddleware
  PROTECTED_PREFIXES = [ "/api/v1", "/v1" ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"].to_s
    return @app.call(env) unless protected_path?(path)

    unless env["REQUEST_METHOD"].to_s.casecmp("GET").zero?
      return json_error(
        env,
        status: 405,
        headers_extra: { "Allow" => "GET" },
        code: "METHOD_NOT_ALLOWED",
        message: "Only GET is supported on #{path}. Received #{env["REQUEST_METHOD"].to_s.upcase}.",
        hint: "Use GET /api/v1/phones/random or GET /v1/phones/random."
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
