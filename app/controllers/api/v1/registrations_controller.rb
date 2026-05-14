module Api
    module V1
        class RegistrationsController < ApplicationController
            def create
                user = User.new(user_params)
                if user.save
                    render json: {token: JsonWebToken.encode(user_id: user.id), user: user_json(user)}, status: :created
                else
                    render json: {errors: user.errors.full_messages}, status: :unprocessable_entity
                end
            end

            private

            def user_params
                params.require(:user).permit(:email, :password, :password_confirmation, :timezone, :display_name)
            end

            def user_json(user)
                { id: user.id, email: user.email, timezone: user.timezone, display_name: user.display_name }.compact
            end
        end
    end
end

            