# frozen_string_literal: true

# Arbitrary JSON stored from POST /api/v1/stored_payloads; id is returned as opaque index.
class StoredPayload < ApplicationRecord
  MAX_BODY_BYTES = 512 * 1024

  scope :recent_first, -> { order(id: :desc) }
end
