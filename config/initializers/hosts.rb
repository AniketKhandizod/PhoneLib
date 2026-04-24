# frozen_string_literal: true

if Rails.env.production?
  # Allow Railway’s generated hostnames (see https://docs.railway.com ).
  Rails.application.config.hosts << ".up.railway.app"
  Rails.application.config.hosts << ENV["RAILWAY_PUBLIC_DOMAIN"] if ENV["RAILWAY_PUBLIC_DOMAIN"].present?
end

ENV.fetch("ALLOWED_HOSTS", "").split(/[,\s]+/).map(&:strip).reject(&:blank?).each do |host|
  Rails.application.config.hosts << host
end
