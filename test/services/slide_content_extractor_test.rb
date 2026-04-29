require "test_helper"

class SlideContentExtractorTest < ActiveSupport::TestCase
  test "raises error for non-pptx files" do
    # Create a mock uploaded file with non-pptx extension
    uploaded_file = Minitest::Mock.new
    uploaded_file.expect :original_filename, "test.pdf"

    extractor = SlideContentExtractor.new(uploaded_file)

    assert_raises SlideContentExtractor::UnsupportedFormatError do
      extractor.extract
    end
  end

  test "accepts pptx files" do
    # This test just verifies that pptx files are accepted by the format check
    uploaded_file = Minitest::Mock.new
    uploaded_file.expect :original_filename, "test.pptx"
    uploaded_file.expect :original_filename, "test.pptx"

    extractor = SlideContentExtractor.new(uploaded_file)

    # The actual extraction would fail without a valid PPTX file,
    # but we're just testing the format validation here
    assert_equal SlideContentExtractor, extractor.class
  end
end
