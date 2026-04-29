# app/services/docx_report_generator.rb
require 'htmltoword'

class DocxReportGenerator
  def initialize(insights)
    @insights = insights
  end

  def save_to(filepath)
    html = generate_html
    
    # Convert HTML to DOCX
    document = Htmltoword::Document.create(html)
    File.open(filepath, 'wb') do |f|
      f.write(document)
    end
    
    filepath
  end

  private

  def generate_html
    # Group by slide number
    insights_by_slide = @insights.group_by(&:slide_number).sort_by(&:first)
    
    html = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; }
          h1 { color: #500000; border-bottom: 3px solid #500000; padding-bottom: 10px; }
          h2 { color: #500000; margin-top: 30px; border-bottom: 1px solid #bdc3c7; padding-bottom: 5px; }
          .image-section { margin: 20px 0; padding: 15px; background-color: #f8f9fa; border-left: 4px solid #500000; }
          .image-name { font-weight: bold; color: #500000; margin-bottom: 5px; }
          .title { font-style: italic; color: #666; margin-bottom: 10px; }
          .analysis { margin-left: 20px; line-height: 1.6; }
          .timestamp { color: #7f8c8d; font-size: 0.9em; margin-bottom: 20px; }
        </style>
      </head>
      <body>
        <h1>Image Analysis Report</h1>
        <p class="timestamp">Generated: #{Time.current.strftime('%B %d, %Y at %I:%M %p')}</p>
    HTML
    
    insights_by_slide.each do |slide_num, slide_insights|
      html += "<h2>Slide #{slide_num}</h2>\n"
      
      slide_insights.each do |insight|
        html += <<~INSIGHT
          <div class="image-section">
            <div class="image-name">#{insight.image_name}</div>
            <div class="title">#{insight.title}</div>
            <div class="analysis">#{insight.analysis}</div>
          </div>
        INSIGHT
      end
    end
    
    html += <<~HTML
      </body>
      </html>
    HTML
    
    html
  end
end