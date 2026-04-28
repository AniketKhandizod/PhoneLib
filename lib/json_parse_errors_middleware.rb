# frozen_string_literal: true

# Malformed JSON in the request body is parsed before controller action; unwrap ParseError from
# wrappers (e.g. ActionController::WrappedException / ActionView::Template::Error) and return JSON.
class JsonParseErrorsMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue StandardError => e
    parse_error = unwrap_json_parse_failure(e)
    raise e unless parse_error

    body = unified_error_payload(env, parse_error)
    json = ActiveSupport::JSON.encode(body)

    headers = Rack::Headers.new.tap do |h|
      h["Content-Type"] = "application/json; charset=UTF-8"
      h["Content-Length"] = json.bytesize.to_s
      h.delete("WWW-Authenticate")
    end

    [ 400, headers, [ json ] ]
  end

  private

  def unwrap_json_parse_failure(e)
    current = e
    20.times do
      break unless current

      return current if json_parse_related?(current)

      current = current.cause
    end

    json_parse_related?(e) ? e : nil
  end

  def json_parse_related?(e)
    e.is_a?(ActionDispatch::Http::Parameters::ParseError) ||
      (e.respond_to?(:message) &&
        /Error occurred while parsing request parameters/o.match?(e.message.to_s))
  rescue StandardError
    false
  end

  # Matches ApiRenderable error shape without loading controller layer.
  def unified_error_payload(env, exception)
    req = ActionDispatch::Request.new(env)
    rid = req.request_id || env["action_dispatch.request_id"]

    {
      success: false,
      meta: {
        request_id: rid,
        timestamp: Time.current.iso8601(3)
      },
      error: {
        code: "INVALID_JSON",
        message: "Request body could not be parsed as JSON.",
        hint: "Use Content-Type: application/json and valid JSON (double-quoted keys, no trailing commas).",
        details: [
          {
            message: friendly_parse_message(exception)
          }
        ]
      }
    }
  end

  def friendly_parse_message(exception)
    msg = exception.message.to_s
    return msg if msg.length > 240

    msg
  rescue StandardError
    "Invalid JSON syntax"
  end
end
