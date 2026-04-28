# frozen_string_literal: true

require "ipaddr"

# Blocks /api/v1/* and /v1/* unless the client IP matches ALLOWED_CLIENT_IP (default 27.107.44.138).
# Skips /up and other non-API paths. Uses ActionDispatch::Request#remote_ip (X-Forwarded-For aware).
class ClientIpRestrictionMiddleware
  PROTECTED_PREFIXES = [ "/api/v1", "/v1" ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"].to_s

    return @app.call(env) unless protected_api_path?(path)

    request = ActionDispatch::Request.new(env)
    return @app.call(env) if client_ip_allowed?(request)

    body = forbidden_payload(env, request)
    json = ActiveSupport::JSON.encode(body)

    headers = Rack::Headers.new.tap do |h|
      h["Content-Type"] = "application/json; charset=UTF-8"
      h["Content-Length"] = json.bytesize.to_s
    end

    [ 403, headers, [ json ] ]
  end

  private

  def protected_api_path?(path)
    return false if path == "/up"

    PROTECTED_PREFIXES.any? { |p| path == p || path.start_with?("#{p}/") }
  end

  def client_ip_allowed?(request)
    allowed = allowed_ip_string
    return true if allowed.blank?

    seen = request.remote_ip.to_s.strip
    same_ip?(seen, allowed)
  end

  def allowed_ip_string
    ENV.fetch("ALLOWED_CLIENT_IP", "27.107.44.138").to_s.strip
  end

  def same_ip?(seen, allowed)
    IPAddr.new(seen) == IPAddr.new(allowed)
  rescue IPAddr::InvalidAddressError
    seen == allowed
  end

  def forbidden_payload(env, request)
    allowed = allowed_ip_string
    seen = request.remote_ip.to_s.strip
    rid = request.request_id || env["action_dispatch.request_id"]

    {
      success: false,
      meta: {
        request_id: rid,
        timestamp: Time.current.iso8601(3)
      },
      error: {
        code: "FORBIDDEN_CLIENT_IP",
        message: "Access denied: this API only accepts requests from ALLOWED_CLIENT_IP (#{allowed}). " \
                 "Your request was seen as #{seen} (from REMOTE_ADDR / X-Forwarded-For).",
        hint: "Set the Railway environment variable ALLOWED_CLIENT_IP to the public IP that should call this API " \
              "(default is 27.107.44.138 if unset). For local tests, set ALLOWED_CLIENT_IP to 127.0.0.1."
      }
    }
  end
end
