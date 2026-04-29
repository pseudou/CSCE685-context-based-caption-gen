class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :force_dev_login, if: -> { Rails.env.development? && ENV["BYPASS_LOGIN"] == "true" }
  before_action :require_login

  private

  def force_dev_login
    return if session[:user_id].present?

    user = User.find_or_create_by!(email: "dev@example.com") do |u|
      u.first_name = "Dev"
      u.last_name = "User"
      u.uid = "dev-user"
      u.provider = "developer"
    end

    session[:user_id] = user.id
  end

  def current_user
    # if @current _user is undefined or falsy, evaluate the RHS
    #   RHS := look up user by id only if user id is in the session hash
    # question: what happens if session has user_id but DB does not?
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def logged_in?
    # current_user returns @current_user,
    #   which is not nil (truthy) only if session[:user_id] is a valid user id
    current_user
  end

  def require_login
    # redirect to the welcome page unless user is logged in
    unless logged_in?
      redirect_to welcome_path
    end
  end
end
