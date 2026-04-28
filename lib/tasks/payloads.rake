# frozen_string_literal: true

namespace :payloads do
  desc "Delete all stored JSON payloads (same as StoredPayloadPurgeJob). Schedule daily at 00:00 (e.g. Railway cron: 0 0 * * * TZ=UTC)."
  task purge: :environment do
    n = StoredPayloadPurgeJob.perform_now
    puts "Deleted #{n} stored payload(s)."
  end
end
