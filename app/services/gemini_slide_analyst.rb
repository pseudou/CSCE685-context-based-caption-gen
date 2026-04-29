require "faraday"
require "json"
require "base64"

class GeminiSlideAnalyst
  DEFAULT_API_BASE_URL = "https://generativelanguage.googleapis.com".freeze
  API_PATH_TEMPLATE = "/v1beta/models/%{model}:generateContent".freeze

  # Hard limits requested
  DEFAULT_MAX_RPM = 30
  DEFAULT_MAX_RPD = 14_400
  DEFAULT_MAX_TPM = 15_000

  Config = Struct.new(
    :api_key,
    :model,
    :context_window,
    :max_retries,
    :base_backoff,
    :response_mime_type,
    :max_rpm,
    :max_rpd,
    :max_tpm,
    keyword_init: true
  )

  RateLimitState = Struct.new(
    :minute_window_started_at,
    :minute_requests,
    :minute_tokens,
    :day_started_at,
    :day_requests,
    keyword_init: true
  )

  SlideInsight = Struct.new(
    :slide_number,
    :image_name,
    :title,
    :analysis,
    keyword_init: true
  )

  class MissingApiKeyError < StandardError; end
  class ApiError < StandardError; end

  def initialize(
    api_key:,
    model: "gemma-3-27b-it",
    context_window: 4,
    max_retries: 5,
    base_backoff: 1.0,
    api_base_url: DEFAULT_API_BASE_URL,
    response_mime_type: nil,
    max_rpm: DEFAULT_MAX_RPM,
    max_rpd: DEFAULT_MAX_RPD,
    max_tpm: DEFAULT_MAX_TPM
  )
    raise MissingApiKeyError, "Set GEMINI_API_KEY to enable LLM analysis" if api_key.blank?

    @config = Config.new(
      api_key: api_key,
      model: model,
      context_window: context_window,
      max_retries: max_retries,
      base_backoff: base_backoff,
      response_mime_type: response_mime_type,
      max_rpm: max_rpm.to_i,
      max_rpd: max_rpd.to_i,
      max_tpm: max_tpm.to_i
    )

    now = Time.now
    @rate_limit_state = RateLimitState.new(
      minute_window_started_at: now,
      minute_requests: 0,
      minute_tokens: 0,
      day_started_at: now,
      day_requests: 0
    )

    @connection = Faraday.new(url: api_base_url) do |faraday|
      faraday.request :json
      faraday.adapter Faraday.default_adapter
      # NOTE: Removed :raise_error to manually handle status codes for retry logic.
    end
  end

  def analyze(slides)
    context = []
    slides.map do |slide|
      title = request_with_retry(build_payload(title_prompt(context), slide))
      analysis = request_with_retry(build_payload(analysis_prompt(context, title), slide))

      context << { slide: slide.slide_number, title: title }
      context.shift while context.size > @config.context_window

      SlideInsight.new(
        slide_number: slide.slide_number,
        image_name: slide.image_name,
        title: title,
        analysis: analysis
      )
    end
  end

  private

  def endpoint_path
    API_PATH_TEMPLATE % { model: @config.model }
  end

  def build_payload(prompt_text, slide)
    payload = {
      "contents" => [
        {
          "parts" => [
            { "text" => prompt_text },
            {
              "inline_data" => {
                "mime_type" => slide.mime_type,
                "data" => Base64.strict_encode64(slide.binary)
              }
            }
          ]
        }
      ]
    }

    return payload unless @config.response_mime_type.present?

    payload.merge(
      "generationConfig" => {
        "responseMimeType" => @config.response_mime_type
      }
    )
  end

  def enforce_rate_limits!(payload)
    now = Time.now
    state = @rate_limit_state

    # Day window
    if now - state.day_started_at >= 24 * 60 * 60
      state.day_started_at = now
      state.day_requests = 0
    end

    if state.day_requests >= @config.max_rpd
      raise ApiError, "Daily request limit reached (#{@config.max_rpd} RPD)"
    end

    # Minute window
    if now - state.minute_window_started_at >= 60
      state.minute_window_started_at = now
      state.minute_requests = 0
      state.minute_tokens = 0
    end

    # Approx token estimate for TPM guardrail.
    # This is conservative-ish and intentionally simple.
    estimated_tokens = (payload.to_json.bytesize / 4.0).ceil

    # If we're going to exceed either RPM or TPM, sleep until next minute boundary.
    if state.minute_requests >= @config.max_rpm || (state.minute_tokens + estimated_tokens) > @config.max_tpm
      sleep_seconds = 60 - (now - state.minute_window_started_at)
      sleep(sleep_seconds) if sleep_seconds.positive?

      state.minute_window_started_at = Time.now
      state.minute_requests = 0
      state.minute_tokens = 0
    end

    state.minute_requests += 1
    state.minute_tokens += estimated_tokens
    state.day_requests += 1
  end

  def request_with_retry(payload)
    retries = 0

    begin
      enforce_rate_limits!(payload)

      response = @connection.post(
        endpoint_path,
        payload.to_json,
        { "Content-Type" => "application/json" }
      ) do |req|
        req.params["key"] = @config.api_key
      end

      case response.status
      when 200
        # ok
      when 429
        raise ApiError, "Rate limited (429)" # retry
      when 500..599
        raise ApiError, "Server error (#{response.status})" # retry
      else
        # 4xx generally shouldn't be retried; include body for debugging.
        raise ApiError, "Request failed (#{response.status}): #{safe_error_message(response.body)}"
      end

      body = JSON.parse(response.body)

      # Gemini-style response:
      # { candidates: [ { content: { parts: [ { text: "..." } ] } } ] }
      text = body.dig("candidates", 0, "content", "parts", 0, "text")&.strip
      return text if text.present?

      raise ApiError, "Empty or malformed response"
    rescue ApiError => e
      if (e.message.include?("429") || e.message.include?("Server error")) && retries < @config.max_retries
        sleep backoff_delay(retries)
        retries += 1
        retry
      end
      raise
    rescue JSON::ParserError => e
      raise ApiError, "Failed to parse JSON response: #{e.message}"
    rescue Faraday::Error => e
      status = e.response&.dig(:status)
      if status == 429 && retries < @config.max_retries
        sleep backoff_delay(retries)
        retries += 1
        retry
      elsif status && status >= 500 && retries < @config.max_retries
        sleep backoff_delay(retries)
        retries += 1
        retry
      else
        raise ApiError, "HTTP error #{status || 'N/A'}: #{e.message}"
      end
    end
  end

  def safe_error_message(raw_body)
    JSON.parse(raw_body).dig("error", "message")
  rescue JSON::ParserError, TypeError
    raw_body.to_s.tr("\n", " ").strip.first(500)
  end

  def backoff_delay(retries)
    jitter = rand * 0.25
    (@config.base_backoff * (2 ** retries)) + jitter
  end

  def title_prompt(context)
    context_lines = context.map { |entry| "Slide #{entry[:slide]}: #{entry[:title]}" }
    <<~PROMPT
      You are an assistant that writes concise, vivid, context-based slide image titles.
      The PPT may contain up to 50 slides. Analyze the provided slide image and reply with a single compelling title (max 12 words).
      Highlight setting, subject, and intent in an inclusive tone. Avoid numbering or extra commentary.

      Prior slide titles for context:
      #{context_lines.presence || "None yet — this is the first slide in scope."}
    PROMPT
  end

  def analysis_prompt(context, current_title)
    context_lines = context.map { |entry| "Slide #{entry[:slide]}: #{entry[:title]}" }
    <<~PROMPT
      You are an assistant that writes detailed, context-based image descriptions.

      Current slide title: #{current_title}

      Prior slide titles for context:
      #{context_lines.presence || "None yet — this is the first slide in scope."}

      Provide a detailed description (2-3 sentences) of this image that:
      - Describes the visual content clearly and accurately
      - Connects to the presentation's narrative flow based on previous slides
      - Uses an inclusive, professional tone
      - Avoids phrases like "this image shows" or "the slide contains"
      - Focuses on the key information conveyed by the image

      Reply with only the description, no extra commentary.
    PROMPT
  end
end
