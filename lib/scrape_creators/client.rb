# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'zlib'
require 'stringio'

module ScrapeCreators
  class Client
    TIKTOK = 'tiktok'
    INSTAGRAM = 'instagram'

    attr_reader :config, :api_key

    def initialize(config = nil, api_key: nil)
      @config = config || ScrapeCreators.configuration
      @api_key = api_key || @config.api_key
    end

    def posts_url_for(source:)
      case source
      when TIKTOK then '/v3/tiktok/profile/videos'
      when INSTAGRAM then '/v2/instagram/user/posts'
      else '/404'
      end
    end

    def post_url_for(source:)
      case source
      when TIKTOK then '/v2/tiktok/video'
      when INSTAGRAM then '/v1/instagram/post'
      else '/404'
      end
    end

    def comments_url_for(source:)
      case source
      when TIKTOK then '/v1/tiktok/video/comments'
      when INSTAGRAM then '/v2/instagram/post/comments'
      else '/404'
      end
    end

    def posts_key_for(source:)
      case source
      when TIKTOK then 'aweme_list'
      when INSTAGRAM then 'items'
      else 'items'
      end
    end

    def posts(handle, options = {})
      params = { handle: }.merge(options)
      source = options.dig(:source) || 'instagram'
      posts_url = posts_url_for(source:)
      res = get(posts_url, params)
      key = posts_key_for(source:)
      res.is_a?(Hash) ? (res[key] || []) : []
    end

    def post(url_or_code, options = {})
      url = normalize_url(url_or_code)
      source = options.dig(:source) || 'instagram'
      post_url = post_url_for(source:)
      params = { url: url }.merge(options)
      get(post_url, params)
    end

    def comments(url_or_code, options = {})
      url = normalize_url(url_or_code)
      params = { url: url }.merge(options)
      source = options.dig(:source) || 'instagram'
      comments_url = comments_url_for(source:)
      res = get(comments_url, params)
      res.is_a?(Hash) ? (res["comments"] || []) : []
    end

    def get(endpoint, params = {}, options = {})
      request(endpoint, method: :get, params: params, options: options)
    end

    def request(endpoint, method: :get, params: {}, options: {})
      current_key = options[:api_key] || api_key
      if current_key.nil? || current_key.to_s.strip.empty?
        raise ConfigurationError, "Scrape Creators API key is missing. Set ENV['SCRAPE_CREATORS_API_KEY'] or configure via ScrapeCreators.configure { |c| c.api_key = '...' }"
      end

      clean_endpoint = endpoint.to_s.start_with?('/') ? endpoint.to_s : "/#{endpoint}"
      base_url = options[:api_base_url] || config.api_base_url
      url_str = "#{base_url}#{clean_endpoint}"

      uri = URI.parse(url_str)

      if method == :get
        uri.query = URI.encode_www_form(params) if params && !params.empty?
        req = Net::HTTP::Get.new(uri.request_uri)
      else
        req = Net::HTTP::Post.new(uri.request_uri)
        req['Content-Type'] = 'application/json'
        req.body = JSON.generate(params) if params && !params.empty?
      end

      req['x-api-key'] = current_key
      req['Accept'] = 'application/json'
      req['Accept-Encoding'] = 'gzip, deflate'

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = options[:open_timeout] || config.open_timeout
      http.read_timeout = options[:read_timeout] || config.read_timeout

      res = http.request(req)
      parse_response(res)
    end

    private

    def normalize_url(url_or_code)
      str = url_or_code.to_s.strip
      if str.start_with?('http://', 'https://')
        str
      else
        "https://www.instagram.com/p/#{str}/"
      end
    end

    def parse_response(response)
      body = response.body

      if response['Content-Encoding'] == 'gzip' && body && !body.empty?
        begin
          body = Zlib::GzipReader.new(StringIO.new(body)).read
        rescue Zlib::Error, Zlib::GzipFile::Error
          # Decompression fallback
        end
      elsif response['Content-Encoding'] == 'deflate' && body && !body.empty?
        begin
          body = Zlib::Inflate.inflate(body)
        rescue Zlib::Error
          # Decompression fallback
        end
      end

      parsed = begin
        JSON.parse(body)
      rescue JSON::ParserError
        body
      end

      unless response.is_a?(Net::HTTPSuccess)
        error_msg = if parsed.is_a?(Hash)
                      parsed['detail'] || parsed['message'] || parsed['error'] || response.message
                    else
                      response.message
                    end
        raise APIError.new("ScrapeCreators Error (#{response.code}): #{error_msg}", status: response.code.to_i, response_body: body)
      end

      parsed
    end
  end
end
