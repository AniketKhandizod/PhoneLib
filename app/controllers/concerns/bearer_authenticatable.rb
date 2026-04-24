# frozen_string_literal: true

# Expects Authorization: Bearer <API_BEARER_TOKEN>
# Set API_BEARER_TOKEN in the Railway service variables (or .env for local use).
module BearerAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_bearer
  end

  private

  def authenticate_bearer
    expected = required_bearer_token
    if expected.blank?
      render_misconfiguration "Set API_BEARER_TOKEN in the environment (e.g. Railway service variables)"
      return
    end

    token = bearer_token
    if token.blank? || !secure_token_match?(token, expected)
      render_unauthorized "Invalid or missing bearer token"
    end
  end

  def required_bearer_token
    @required_bearer_token ||= ENV.fetch("API_BEARER_TOKEN", nil)
  end

  def bearer_token
    header = request.authorization.to_s
    m = header.match(/\ABearer[[:space:]]+(.+)\z/m)
    m ? m[1].strip : nil
  end

  def render_unauthorized(message)
    response.headers["WWW-Authenticate"] = "Bearer"
    render json: { error: { code: "unauthorized", message: message } }, status: :unauthorized
  end

  def render_misconfiguration(message)
    render json: { error: { code: "misconfiguration", message: message } }, status: :service_unavailable
  end

  def secure_token_match?(token, expected)
    return false if token.blank? || expected.blank? || token.bytesize != expected.bytesize

    ActiveSupport::SecurityUtils.secure_compare(token, expected)
  end
end
