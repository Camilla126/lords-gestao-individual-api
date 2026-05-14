module Api
    module V1
        class MeController < BaseController
            before_action :authenticate_user!

            def show
                render json: { user: user_json(current_user) }, status: :ok
            end

            def update
                if current_user.update(me_params)
                    render json: { user: user_json(current_user) }, status: :ok
                else
                    render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
                end
            end

            private

            def me_params
                params.require(:user).permit(:timezone, :display_name)
            end

            def user_json(user)
                { id: user.id, email: user.email, timezone: user.timezone, display_name: user.display_name }.compact
            end 
        end
    end
end

            
      