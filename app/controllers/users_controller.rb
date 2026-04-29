class UsersController < ApplicationController
  def show
    if params[:id].to_i != current_user.id
      redirect_to user_path(current_user), alert: "Access denied."
      return
    end

    @current_user = User.find(params[:id])

    # Load analysis summary from JSON file (if path in session)
    @analysis_results = []
    if (json_path = session[:analysis_json_path]) && File.exist?(json_path)
      begin
        data = JSON.parse(File.read(json_path))
        @analysis_results = data.map { |h| { slide_number: h["slide_number"], image_name: h["image_name"], title: h["title"] } }
      rescue => e
        Rails.logger.error "Failed to read analysis JSON: #{e.class}: #{e.message}"
      end
    end

    # Report readiness based on either existing docx or JSON available to regenerate
    analysis_path = session[:analysis_report_path]
    json_path = session[:analysis_json_path]
    @analysis_report_ready = (analysis_path.present? && File.exist?(analysis_path.to_s)) || (json_path.present? && File.exist?(json_path.to_s))
    @analysis_report_filename = session[:analysis_report_filename]

    caption_path = session[:caption_report_path]
    @caption_report_ready = caption_path.present? && File.exist?(caption_path.to_s)
    @caption_report_filename = session[:caption_report_filename]
  end
end
