class JsonWebToken
    EXP = 24.hours

    class << self
        def encode(user_id:, exp: Time.current + EXP)
            payload = { sub: user_id, exp: exp.to_i }
            JWT.encode(payload, secret, "HS256")
        end

        def decode(token)
            return nil if token.blank?

            JWT.decode(token, secret, true, { algorithm: "HS256" }).first.symbolize_keys
        rescue JWT::DecodeError
            nil
        end

        private

        def secret
            key = Rails.application.credentials[:jwt_secret].presence || ENV["JWT_SECRET"]
            raise "Missing jwt_secret in credentials or JWT_SECRET in ENV" if key.blank?

            key
        end
    end
end