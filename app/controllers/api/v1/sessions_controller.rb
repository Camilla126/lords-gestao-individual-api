module Api
    module V1
        class SessionsController < ApplicationController
            def create
                user = User.find_by(email: session_params[:email].to_s.strip.downcase)
                if user&.authenticate(session_params[:password])
                    render json: { token: JsonWebToken.encode(user_id: user.id), user: user_json(user) }, status: :ok
                else
                    render json: { error: "Invalid credentials" }, status: :unauthorized
                end
            end

            private

            def session_params
                params.permit(:email, :password)
            end

            def user_json(user)
                { id: user.id, email: user.email, timezone: user.timezone, display_name: user.display_name }.compact
            end
        end
    end
end

            