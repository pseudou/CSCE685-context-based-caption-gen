require "test_helper"

class DocxReportGeneratorTest < ActiveSupport::TestCase
  test "initializes with insights array" do
    insights = []
    generator = DocxReportGenerator.new(insights)
    assert_equal DocxReportGenerator, generator.class
  end

  test "generates HTML report for insights" do
    insight = Struct.new(:slide_number, :image_name, :title, :analysis, keyword_init: true).new(
      slide_number: 1,
      image_name: "slide1.png",
      title: "Test title",
      analysis: "A test analysis for testing purposes."
    )

    generator = DocxReportGenerator.new([insight])
    html = generator.send(:generate_html)

    assert_includes html, "Image Analysis Report"
    assert_includes html, "Slide 1"
    assert_includes html, "slide1.png"
    assert_includes html, "Test title"
    assert_includes html, "A test analysis for testing purposes."
  end
end
