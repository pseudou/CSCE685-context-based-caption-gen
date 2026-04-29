class WorkspaceController < ApplicationController
  require 'ostruct'
  require 'json'

  def upload
    deck = params[:deck]
    unless deck.present?
      redirect_back fallback_location: user_path(current_user), alert: 'Please choose a PPT file before uploading.'
      return
    end

    extractor = PptImageExtractor.new(deck)
    slide_images = extractor.extract
    if slide_images.empty?
      redirect_back fallback_location: user_path(current_user), alert: 'No slide images detected in this PPTX.'
      return
    end

    Rails.logger.debug "GEMINI_API_KEY present?: #{ENV['GEMINI_API_KEY'].present?}" # do not log key value

    analyst = GeminiSlideAnalyst.new(
      api_key: ENV["GEMINI_API_KEY"],
      model: ENV.fetch("GEMINI_MODEL", "gemma-3-27b-it"),
      context_window: ENV.fetch("GEMINI_CONTEXT_WINDOW", 4).to_i
    )

    insights = analyst.analyze(slide_images)

    # Persist insights to JSON file instead of stuffing session (avoid cookie overflow)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    analysis_dir = Rails.root.join("tmp", "analysis")
    FileUtils.mkdir_p(analysis_dir) unless Dir.exist?(analysis_dir)
    json_filename = "analysis_#{current_user.id}_#{timestamp}.json"
    json_filepath = analysis_dir.join(json_filename)
    File.write(json_filepath, JSON.pretty_generate(insights.map { |i| {
      slide_number: i.slide_number,
      image_name: i.image_name,
      title: i.title,
      analysis: i.analysis
    } }))
    session[:analysis_json_path] = json_filepath.to_s
    session[:analysis_json_filename] = json_filename

    # Generate a DOCX report (full insight with titles + analyses)
    reports_dir = Rails.root.join("tmp", "reports")
    FileUtils.mkdir_p(reports_dir) unless Dir.exist?(reports_dir)
    docx_filename = "analysis_report_#{timestamp}.docx"
    docx_filepath = reports_dir.join(docx_filename)
    DocxReportGenerator.new(insights).save_to(docx_filepath)
    session[:analysis_report_path] = docx_filepath.to_s
    session[:analysis_report_filename] = docx_filename

    redirect_to user_path(current_user), notice: "Analyzed #{insights.count} slide image#{'s' unless insights.count == 1}. Analysis report ready for download."
  rescue PptImageExtractor::UnsupportedFormatError,
         PptImageExtractor::SlideLimitExceeded,
         GeminiSlideAnalyst::MissingApiKeyError,
         GeminiSlideAnalyst::ApiError => e
    Rails.logger.debug { "Upload analysis error: #{e.class}: #{e.message}" }
    redirect_back fallback_location: user_path(current_user), alert: "An error occurred while processing your request. Please try again later."
  end

  def download_analysis_report
    filepath = session[:analysis_report_path]
    filename = session[:analysis_report_filename]

    # If DOCX missing but JSON exists, regenerate
    unless filepath && File.exist?(filepath)
      json_path = session[:analysis_json_path]
      if json_path && File.exist?(json_path)
        begin
          data = JSON.parse(File.read(json_path))
          objects = data.map do |h|
            obj = OpenStruct.new
            h.each { |k, v| obj[k] = v }
            obj
          end
          reports_dir = Rails.root.join("tmp", "reports")
          FileUtils.mkdir_p(reports_dir) unless Dir.exist?(reports_dir)
          timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
          filename = "analysis_report_#{timestamp}.docx"
          filepath = reports_dir.join(filename)
          DocxReportGenerator.new(objects).save_to(filepath)
          session[:analysis_report_path] = filepath.to_s
          session[:analysis_report_filename] = filename
        rescue => e
          Rails.logger.error "Failed to regenerate analysis report from JSON: #{e.class}: #{e.message}"
          redirect_to user_path(current_user), alert: "Analysis report could not be regenerated. Please re-run slide analysis." and return
        end
      else
        redirect_to user_path(current_user), alert: "Analysis report not found. Please re-run slide analysis." and return
      end
    end

    send_file filepath, filename: filename, type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", disposition: "attachment"
    # Keep paths to allow re-download; do not delete
  end
end
