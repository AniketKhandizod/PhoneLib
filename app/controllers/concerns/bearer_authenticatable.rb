# frozen_string_literal: true

# Expects Authorization: Bearer <API_BEARER_TOKEN>
# Set API_BEARER_TOKEN in the Railway service variables (or .env for local use).
# Include ApiRenderable before this concern so standardized JSON errors resolve.
module BearerAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_bearer
  end

  private

  def authenticate_bearer
    expected = required_bearer_token
    if expected.blank?
      render_error(
        code: "AUTH_SERVER_MISCONFIGURATION",
        message: "Authentication is not configured on this server.",
        status: :service_unavailable,
        hint: "Set API_BEARER_TOKEN (e.g. Railway service variables) and redeploy."
      )
      return
    end

    auth_header_raw = authorization_header_value
    if auth_header_raw.blank?
      render_error(
        code: "AUTHORIZATION_MISSING",
        message: "Missing Authorization header.",
        status: :unauthorized,
        hint: "Send exactly: Authorization: Bearer <your token that matches API_BEARER_TOKEN>."
      )
      configure_www_authenticate
      return
    end

    unless bearer_scheme?(auth_header_raw)
      render_error(
        code: "AUTHORIZATION_SCHEME_INVALID",
        message: 'Authorization header must use the Bearer scheme (e.g. "Bearer YOUR_TOKEN_HERE").',
        status: :unauthorized,
        hint: "Use the format Bearer <token>, not Basic, Digest, or a raw token without the Bearer prefix."
      )
      configure_www_authenticate
      return
    end

    token = bearer_token_from_header(auth_header_raw)
    if token.blank?
      render_error(
        code: "BEARER_TOKEN_EMPTY",
        message: "Bearer token is empty after the Bearer prefix.",
        status: :unauthorized,
        hint: "Provide your API token immediately after Bearer with a single space."
      )
      configure_www_authenticate
      return
    end

    return if ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected.to_s)

    render_error(
      code: "BEARER_TOKEN_MISMATCH",
      message: "The bearer token does not match the server's configured API_BEARER_TOKEN.",
      status: :unauthorized,
      hint: "Use the exact token configured for this environment (Railway variable API_BEARER_TOKEN). " \
            "Trailing spaces or the wrong deployment's secret cause this."
    )
    configure_www_authenticate
  end

  def authorization_header_value
    request.get_header("HTTP_AUTHORIZATION").presence ||
      request.get_header("Authorization").presence ||
      request.authorization.to_s.presence
  end

  def bearer_scheme?(header)
    header.to_s.strip.match?(/\ABearer\b/i)
  end

  def bearer_token_from_header(header)
    m = header.to_s.strip.match(/\ABearer\b[[:space:]]*(.*)\z/m)
    m ? m[1].to_s.strip.presence : nil
  end

  def required_bearer_token
    @required_bearer_token ||= ENV.fetch("API_BEARER_TOKEN", nil)
  end

  def configure_www_authenticate
    response.headers["WWW-Authenticate"] = %(Bearer realm="API", charset="UTF-8")
  end
end
