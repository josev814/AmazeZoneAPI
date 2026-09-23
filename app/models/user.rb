class User < ApplicationRecord
  has_secure_password

  # An e-mail address is the login identifier, so it must be present, a
  # well-formed address, and unique (case-insensitively).
  EMAIL_REGEX = URI::MailTo::EMAIL_REGEXP

  validates :email_address, presence: true,
                            uniqueness: { case_sensitive: false },
                            format: { with: EMAIL_REGEX }
end
