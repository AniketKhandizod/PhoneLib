# frozen_string_literal: true

# Loaded explicitly (not via Zeitwerk) so it is available when initializers run.
require Rails.root.join("lib/server_access_log_middleware").to_s

Rails.application.config.middleware.insert_after(
  ActionDispatch::RequestId,
  ServerAccessLogMiddleware
)
