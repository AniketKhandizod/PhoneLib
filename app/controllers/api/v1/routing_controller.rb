# frozen_string_literal: true

module Api
  module V1
    # Catch-all for /api/v1/* paths with no matching route (no auth required).
    class RoutingController < ApplicationController
      include ApiRenderable

      def not_found
        render_error(
          code: "ROUTE_NOT_FOUND",
          message: "No API route matched this request.",
          status: :not_found,
          details: [
            {
              method: request.request_method,
              path: request.path
            }
          ],
          hint: "Confirm the path and HTTP method. Example: GET /api/v1/phones/random (note spelling: random, not randon)."
        )
      end
    end
  end
end
