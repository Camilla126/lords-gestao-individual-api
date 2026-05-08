module Authenticable
    extend ActiveSupport::Concern

    private

    def authenticate_user!
        return if current_user

        render json: { error: "Unauthorized" }, status: :unauthorized
    end

    def current_user
        @current_user ||= begin
            header = request.headers["Authorization"].to_s
            token = header.split.last
            payload = JsonWebToken.decode(token)
            return nil unless payload && payload[:sub]

            User.find_by(id: payload[:sub])
        end
    end
end