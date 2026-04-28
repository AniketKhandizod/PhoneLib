# frozen_string_literal: true

# Invoked by rake payloads:purge or recurring runner; deletes all rows in stored_payloads.
class StoredPayloadPurgeJob < ApplicationJob
  queue_as :default

  def perform
    n = StoredPayload.delete_all
    Rails.logger.info("[StoredPayloadPurgeJob] deleted #{n} stored payload(s).")
    n
  end
end
