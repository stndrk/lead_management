# frozen_string_literal: true

class AuthUsers < ApplicationRecord
  include BCrypt

  def authenticate(password)
    BCrypt::Password.new(encrypted_password) == password
  end
end
