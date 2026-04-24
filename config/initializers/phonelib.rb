# frozen_string_literal: true

# Stricter checks against possible length (libphonenumber rules).
Phonelib.strict_check = true

# Load libphonenumber data at boot in production to avoid a cold-request GC spike
# and to catch load errors on deploy.
Rails.application.config.after_initialize do
  Phonelib.eager_load! if Rails.env.production?
end
