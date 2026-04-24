# frozen_string_literal: true

require "socket"
require "rack/body_proxy"

# One-line request logs to STDOUT (mirrors the Node "n" project requestLogger):
#   IST 12h time | Server - ip | Requester - ip | METHOD path | N.NNNNs | status
# Visible in Railway: service → Observability → Logs, and in local `rails s` output.
class ServerAccessLogMiddleware
  TZ_IST = "Asia/Kolkata"

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless log_enabled?

    start = monotonic
    request = ActionDispatch::Request.new(env)
    ensure_request_id!(env, request)
    line = build_request_line(request, env)
    status, headers, body = @app.call(env)
    h = with_request_id_header(headers, request.request_id)
    [ status, h, body_proxy(line, start, request, status, body) ]
  end

  private

  def log_enabled?
    if ENV["SERVER_ACCESS_LOG"].present?
      ActiveModel::Type::Boolean.new.cast(ENV["SERVER_ACCESS_LOG"])
    else
      !Rails.env.test?
    end
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def ensure_request_id!(env, request)
    return if request.request_id.present?

    rid = env["action_dispatch.request_id"] || SecureRandom.uuid
    env["action_dispatch.request_id"] = rid
  end

  def build_request_line(request, env)
    method = request.request_method
    path = if env["REQUEST_URI"].to_s.start_with?("/")
      env["REQUEST_URI"]
    else
      request.path + (env["QUERY_STRING"].to_s != "" ? "?#{env['QUERY_STRING']}" : "")
    end
    "#{method} #{path}"
  end

  def with_request_id_header(headers, request_id)
    return headers unless request_id

    h = Rack::Headers.new.merge(headers)
    h["X-Request-Id"] ||= request_id
    h
  end

  def body_proxy(request_line, start, request, status, body)
    body = [ "" ] if body.nil?
    Rack::BodyProxy.new(body) do
      log_line(request_line, start, request, status)
    end
  end

  def log_line(request_line, start, request, status)
    elapsed = monotonic - start
    sec = format("%.4f", elapsed)
    $stdout.puts(
      "#{ist_clock_12h} | Server - #{server_ipv4} | Requester - #{client_ip(request)} | " \
      "#{request_line} | #{sec}s | #{status}"
    )
  end

  def ist_clock_12h
    t = Time.find_zone(TZ_IST)&.now || Time.zone&.now || Time.current
    h = t.strftime("%I").sub(/\A0/, "")
    tzn = t.strftime("%Z")
    "#{h}:#{t.strftime('%M:%S')} #{t.strftime('%p').upcase} #{tzn}"
  end

  def server_ipv4
    return @server_ipv4 if defined?(@server_ipv4) && @server_ipv4

    list = Socket.ip_address_list
    addr = list.find { |a| a.ipv4? && !a.ipv4_loopback? }&.ip_address
    addr ||= list.find { |a| a.ipv4? }&.ip_address
    @server_ipv4 = addr || "0.0.0.0"
  rescue StandardError
    @server_ipv4 = "0.0.0.0"
  end

  def client_ip(request)
    xff = request.get_header("HTTP_X_FORWARDED_FOR")
    if xff.is_a?(String) && xff.strip.present?
      return xff.split(",").first.strip
    end
    if xff.is_a?(Array) && xff[0]
      return xff[0].to_s.strip
    end

    request.remote_ip
  end
end
