OmniAuth.config.allowed_request_methods = [:post, :get]

Rails.application.config.middleware.use OmniAuth::Builder do
  # Prefer ENV (loaded via dotenv in dev/test) but fallback to encrypted credentials
  google_client_id = ENV["GOOGLE_CLIENT_ID"].presence ||
                     Rails.application.credentials.dig(:google, :client_id)
  google_client_secret = ENV["GOOGLE_CLIENT_SECRET"].presence ||
                         Rails.application.credentials.dig(:google, :client_secret)

  if google_client_id.blank? || google_client_secret.blank?
    raise "Google OAuth credentials missing. Set GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET or configure credentials.google."
  end

  provider :google_oauth2, google_client_id, google_client_secret, {
    scope: "email, profile", # Grants access to the user's email and profile information.
    prompt: "select_account", # Allows users to choose the account they want to log in with.
    image_aspect_ratio: "square", # Ensures the profile picture is a square.
    image_size: 50 # Sets the profile picture size to 50x50 pixels.
  }
end
