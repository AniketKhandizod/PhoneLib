# frozen_string_literal: true

# Loaded explicitly (not via Zeitwerk) so it is available when initializers run.
require Rails.root.join("lib/server_access_log_middleware").to_s
require Rails.root.join("lib/client_ip_restriction_middleware").to_s
require Rails.root.join("lib/json_parse_errors_middleware").to_s

# Order: RequestId → IP allowlist → JSON parse errors → access log → app
Rails.application.config.middleware.insert_after(
  ActionDispatch::RequestId,
  ClientIpRestrictionMiddleware
)

Rails.application.config.middleware.insert_after(
  ClientIpRestrictionMiddleware,
  JsonParseErrorsMiddleware
)

Rails.application.config.middleware.insert_after(
  JsonParseErrorsMiddleware,
  ServerAccessLogMiddleware
)
