# frozen_string_literal: true

# GET-only under /api/v1/* and /v1/*; requires matching API_KEY (Rails env / Railway variable), default XYZ789rk@@@.
# Send key as X-Api-Key: <key> or Authorization: Bearer <key>. /up is unrestricted.
class ApiKeyMiddleware
  DEFAULT_API_KEY = "XYZ789rk@@@".freeze
  PROTECTED_PREFIXES = [ "/api/v1", "/v1" ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"].to_s

    return @app.call(env) unless protected_api_path?(path)

    unless env["REQUEST_METHOD"].to_s.casecmp("GET").zero?
      request_early = ActionDispatch::Request.new(env)
      return method_not_allowed_payload(env, request_early)
    end

    key = extracted_api_key(env)
    unless key&.bytesize&.positive?
      request = ActionDispatch::Request.new(env)
      return unauthorized_json(env, request, code: "API_KEY_MISSING", reason: :missing)
    end

    unless timing_safe_matches?(key, configured_api_key)
      request = ActionDispatch::Request.new(env)
      return unauthorized_json(env, request, code: "API_KEY_INVALID", reason: :mismatch)
    end

    @app.call(env)
  end

  private

  def configured_api_key
    ENV["API_KEY"].presence || DEFAULT_API_KEY
  end

  def extracted_api_key(env)
    explicit = env["HTTP_X_API_KEY"].to_s.strip
    return explicit if explicit.present?

    auth = env["HTTP_AUTHORIZATION"].to_s.strip
    m = auth.match(/\ABearer\s+(.+)\z/m)
    return m[1].to_s.strip if m

    nil
  end

  def timing_safe_matches?(provided, expected)
    return false if provided.blank? || expected.blank?

    ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected.to_s)
  end

  def protected_api_path?(path)
    return false if path == "/up"

    PROTECTED_PREFIXES.any? { |p| path == p || path.start_with?("#{p}/") }
  end

  def method_not_allowed_payload(env, request)
    allowed_methods = "GET"
    method = env["REQUEST_METHOD"].to_s.upcase
    rid = request.request_id || env["action_dispatch.request_id"]

    body = {
      success: false,
      meta: {
        request_id: rid,
        timestamp: Time.current.iso8601(3)
      },
      error: {
        code: "METHOD_NOT_ALLOWED",
        message: "Only #{allowed_methods} is supported on #{request.path}. Received #{method}.",
        hint: "This API is read-only. Use GET /api/v1/phones/random or GET /v1/phones/random."
      }
    }
    json = ActiveSupport::JSON.encode(body)
    headers = Rack::Headers.new.tap do |h|
      h["Content-Type"] = "application/json; charset=UTF-8"
      h["Content-Length"] = json.bytesize.to_s
      h["Allow"] = allowed_methods
    end

    [ 405, headers, [ json ] ]
  end

  def unauthorized_json(env, request, code:, reason:)
    rid = request.request_id || env["action_dispatch.request_id"]
    hint =
      case reason
      when :missing
        "Send X-Api-Key: <your key> or Authorization: Bearer <your key>. In Railway set service variable API_KEY (default in app is XYZ789rk@@@)."
      else
        "The key does not match API_KEY configured for this deployment. Rotate API_KEY on Railway if needed."
      end

    message =
      case reason
      when :missing
        "API key missing: send header X-Api-Key or Authorization: Bearer with the configured key."
      else
        "API key invalid or does not match the server configured API_KEY."
      end

    body = {
      success: false,
      meta: {
        request_id: rid,
        timestamp: Time.current.iso8601(3)
      },
      error: {
        code: code.to_s,
        message: message,
        hint: hint
      }
    }

    json = ActiveSupport::JSON.encode(body)

    headers = Rack::Headers.new.tap do |h|
      h["Content-Type"] = "application/json; charset=UTF-8"
      h["Content-Length"] = json.bytesize.to_s
      h["WWW-Authenticate"] = %(ApiKey realm="PhoneLib", charset=UTF-8)
    end

    [ 401, headers, [ json ] ]
  end
end
