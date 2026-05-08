class User < ApplicationRecord
    has_secure_password

    before_validation :normalize_email

    validates :email, presence: true, format: URI::MailTo::EMAIL_REGEXP, uniqueness: { case_insensitive: true }
    validates :timezone, presence: true
    validates :password, presence: true, length: { minimum: 8 }, if: -> { password_digest.nil? || password.present? }
    validates :password_confirmation, presence: true, on: :create

    validate :timezone_must_be_known, if: -> { timezone.present? }

    private

    def normalize_email
        self.email = email.to_s.strip.downcase
    end
    
    def timezone_must_be_known
        TZInfo::Timezone.get(timezone)
    rescue TZInfo::InvalidTimezoneIdentifier
        errors.add(:timezone, "must be a valid IANA timezone (e.g. Europe/Lisbon)")
    end
end

