# frozen_string_literal: true

class HelperController < ActionController::Base
  helper_method :current_user
  protect_from_forgery with: :exception

  def verify_authenticity_token
    if request.format.json?
      # Skip authenticity token check for JSON requests
      true
    else
      super
    end
  end

  private

  def allowed_origin?
    request.headers["HTTP_ORIGIN"] == ENV["AI_ATHOS_API_URL"]
  end

  def current_user
    @current_user ||= AuthUsers.find_by(id: session[:auth_user_id])
  end
end
