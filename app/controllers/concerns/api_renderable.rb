# frozen_string_literal: true

# Standard success/error JSON envelope for the public API.
module ApiRenderable
  extend ActiveSupport::Concern

  private

  def api_meta
    {
      request_id: request.request_id,
      timestamp: Time.current.iso8601(3)
    }
  end

  def render_success(data:, status: :ok)
    render json: {
      success: true,
      meta: api_meta,
      data: data
    }, status: status
  end

  def render_error(code:, message:, status:, details: nil, hint: nil)
    payload = {
      success: false,
      meta: api_meta,
      error: {
        code: code.to_s.upcase,
        message: message
      }
    }
    payload[:error][:hint] = hint if hint.present?
    payload[:error][:details] = details if details.present?
    render json: payload, status: status
  end
end
