# frozen_string_literal: true

# Loaded explicitly (not via Zeitwerk) so it is available when initializers run.
require Rails.root.join("lib/server_access_log_middleware").to_s
require Rails.root.join("lib/api_key_middleware").to_s
require Rails.root.join("lib/json_parse_errors_middleware").to_s

# Order: RequestId → API key gate (GET-only on /api/v1, /v1) → JSON parse errors → access log → app
Rails.application.config.middleware.insert_after(
  ActionDispatch::RequestId,
  ApiKeyMiddleware
)

Rails.application.config.middleware.insert_after(
  ApiKeyMiddleware,
  JsonParseErrorsMiddleware
)

Rails.application.config.middleware.insert_after(
  JsonParseErrorsMiddleware,
  ServerAccessLogMiddleware
)
