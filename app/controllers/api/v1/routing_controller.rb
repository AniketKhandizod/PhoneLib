# frozen_string_literal: true

module Api
  module V1
    # Catch-all for /api/v1/* and /v1/* paths with no matching route (IP allowlist still applies via middleware).
    class RoutingController < ApplicationController
      include ApiRenderable

      def not_found
        render_error(
          code: "ROUTE_NOT_FOUND",
          message: "No GET route for #{request.path}. Use GET /api/v1/phones/random or GET /v1/phones/random.",
          status: :not_found,
          details: [
            {
              method: request.request_method,
              path: request.path
            }
          ],
          hint: "Typo in the path (e.g. phones/randon vs phones/random) or wrong HTTP method causes this."
        )
      end
    end
  end
end
