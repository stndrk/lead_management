# frozen_string_literal: true

# app/controllers/partner_integration/sessions_controller.rb

class SessionsController < HelperController
  def user_login
    # Render the login form (login.html.erb)
  end

  def some_action
    @current_user = current_user
  end

  def create
    if AuthUser.exists?(email: user_params[:email])
      flash[:error] = "User with this email already exists"
      render :login
      return
    end
    password = BCrypt::Password.create(user_params[:password])
    user = AuthUser.new(user_params.except(:password).merge(encrypted_password: password))

    if user.save
      flash[:success] = "User created successfully. Please log in."
      redirect_to login_path
    else
      flash[:error] = "Failed to create user. Please try again."
    end
  end

  def login
    auth_user = AuthUsers.find_by(email: user_params[:email])
    if auth_user.nil? || !auth_user.authenticate(user_params[:password])
      flash[:error] = "Invalid email or password"
      redirect_to "/user_login"
      return
    end
    reset_session_expiration
    session[:auth_user_id] = auth_user.id
    redirect_to "/customers/fetch", notice: "Logged in successfully."
  end

  def logout
    session[:user_id] = nil
    reset_session
    redirect_to "/user_login", notice: "Logged out successfully."
  end

  private

  def user_params
    params.permit(:email, :password, :authenticity_token, :submit)
  end

  def reset_session_expiration
    session[:expires_at] = 30.minutes.from_now
  end
end
