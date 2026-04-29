require "zip"
require "nokogiri"

class PptImageExtractor
  SlideImage = Struct.new(
    :slide_number,
    :image_name,
    :mime_type,
    :binary,
    keyword_init: true
  )

  PPTX_MIME_TYPES = {
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif" => "image/gif",
    ".bmp" => "image/bmp",
    ".webp" => "image/webp"
  }.freeze

  class UnsupportedFormatError < StandardError; end
  class SlideLimitExceeded < StandardError; end

  def initialize(uploaded_file, max_slides: 50)
    @uploaded_file = uploaded_file
    @max_slides = max_slides
  end

  def extract
    ensure_pptx!

    Zip::File.open(tempfile_path) do |zip|
      slides = fetch_slide_entries(zip)
      raise SlideLimitExceeded, "Deck exceeds #{@max_slides} slides" if slides.length > @max_slides

      slides.flat_map.with_index(1) do |entry, idx|
        slide_xml = Nokogiri::XML(entry.get_input_stream.read)
        rels_lookup = build_relationship_lookup(zip, entry)

        slide_xml.xpath("//a:blip/@r:embed", xml_namespaces).map do |node|
          rid = node.value
          target = rels_lookup[rid]
          next unless target

          normalized = normalize_target_path(target)
          image_entry = zip.find_entry(normalized)
          next unless image_entry

          ext = File.extname(image_entry.name).downcase
          mime = PPTX_MIME_TYPES[ext]
          next unless mime

          SlideImage.new(
            slide_number: idx,
            image_name: File.basename(image_entry.name),
            mime_type: mime,
            binary: image_entry.get_input_stream.read
          )
        end.compact
      end
    end
  end

  private

  def tempfile_path
    @uploaded_file.tempfile.flush if @uploaded_file.tempfile.respond_to?(:flush)
    @uploaded_file.tempfile.rewind
    @uploaded_file.tempfile.path
  end

  def ensure_pptx!
    ext = File.extname(@uploaded_file.original_filename.to_s).downcase
    return if ext == ".pptx"

    raise UnsupportedFormatError, "Only .pptx decks are supported for analysis"
  end

  def fetch_slide_entries(zip)
    zip.glob("ppt/slides/slide*.xml").sort_by do |entry|
      entry.name[/slide(\d+)\.xml/, 1].to_i
    end
  end

  def build_relationship_lookup(zip, slide_entry)
    rels_name = slide_entry.name.sub("slides/", "slides/_rels/") + ".rels"
    rels_entry = zip.find_entry(rels_name)
    return {} unless rels_entry

    rels_doc = Nokogiri::XML(rels_entry.get_input_stream.read)
    rels_doc.xpath("//rel:Relationship", rel: "http://schemas.openxmlformats.org/package/2006/relationships").each_with_object({}) do |rel, memo|
      memo[rel["Id"]] = rel["Target"]
    end
  end

  def normalize_target_path(target)
    return target unless target.start_with?("../")

    File.join("ppt", target.delete_prefix("../"))
  end

  def xml_namespaces
    {
      "a" => "http://schemas.openxmlformats.org/drawingml/2006/main",
      "r" => "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    }
  end
end
