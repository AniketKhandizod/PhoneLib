# frozen_string_literal: true

# Placeholder migration so `db:prepare` / schema stay in sync on first deploy.
class InitialSchema < ActiveRecord::Migration[8.0]
  def change
  end
end
