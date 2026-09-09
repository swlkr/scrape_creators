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
    YOUTUBE = 'youtube'

    attr_reader :config, :api_key

    def initialize(config = nil, api_key: nil)
      @config = config || ScrapeCreators.configuration
      @api_key = api_key || @config.api_key
    end

    def posts_url_for(source:)
      case source.to_s
      when TIKTOK then '/v3/tiktok/profile/videos'
      when INSTAGRAM then '/v2/instagram/user/posts'
      when YOUTUBE then '/v1/youtube/channel/shorts'
      else '/404'
      end
    end

    def post_url_for(source:)
      case source.to_s
      when TIKTOK then '/v2/tiktok/video'
      when INSTAGRAM then '/v1/instagram/post'
      when YOUTUBE then '/v1/youtube/video'
      else '/404'
      end
    end

    def comments_url_for(source:)
      case source.to_s
      when TIKTOK then '/v1/tiktok/video/comments'
      when INSTAGRAM then '/v2/instagram/post/comments'
      when YOUTUBE then '/v1/youtube/video/comments'
      else '/404'
      end
    end

    def posts_key_for(source:)
      case source.to_s
      when TIKTOK then 'aweme_list'
      when INSTAGRAM then 'items'
      when YOUTUBE then 'shorts'
      else 'items'
      end
    end

    def search_users(query, source: INSTAGRAM)
      query = query.to_s.strip
      raise ArgumentError, 'Search query is required' if query.empty?

      users = case source.to_s
              when INSTAGRAM
                response = get('/v1/instagram/search', query: query)
                search_results(response).dig('data', 'users').to_a.map do |user|
                  { handle: user['username'], name: user['full_name'], avatar_url: user['profile_pic_url'] }
                end
              when TIKTOK
                response = get('/v1/tiktok/search/users', query: query, trim: true)
                search_results(response).fetch('users', []).map do |user|
                  { handle: user['unique_id'], name: user['nickname'], avatar_url: user.dig('avatar_medium', 'url_list', 0) }
                end
              when YOUTUBE
                response = get('/v1/youtube/search', query: query, type: 'channels')
                search_results(response).fetch('channels', []).map do |channel|
                  { handle: channel['handle'], name: channel['title'], avatar_url: channel['thumbnail'] }
                end
              else
                raise ArgumentError, "Unsupported search source: #{source}"
              end

      users.filter_map do |user|
        handle = user[:handle].to_s.strip.delete_prefix('@')
        next if handle.empty? || handle.match?(%r{[[:space:]/]})

        user.merge(handle: handle)
      end.uniq { |user| user[:handle].downcase }
    end

    def posts(handle, options = {})
      source = (options[:source] || 'instagram').to_s
      pages = options[:pages] || options[:max_pages] || 1
      all_items = []
      cursor = nil
      has_more = true

      pages.to_i.times do
        break unless has_more

        page = posts_page(handle, options.merge(cursor: cursor))
        items = Array(page[:items])
        all_items.concat(items)
        cursor = page[:cursor]
        has_more = page[:has_more] && !cursor.to_s.empty? && !items.empty?
      end

      all_items
    end

    def posts_page(handle, options = {})
      source = (options[:source] || 'instagram').to_s
      params = { handle: handle }
      cursor = options[:cursor] || options['cursor']
      if cursor && !cursor.to_s.empty?
        params[posts_cursor_param_for(source:)] = cursor
      end
      extra = options.reject { |k, _| %w[source cursor max_pages pages].include?(k.to_s) }
      params.merge!(extra)

      res = get(posts_url_for(source:), params)
      key = posts_key_for(source:)
      items = res.is_a?(Hash) ? (res[key] || []) : []
      next_cursor = next_posts_cursor(res, source)
      {
        items: items,
        cursor: next_cursor,
        has_more: posts_has_more?(res, source, next_cursor)
      }
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

    def search_results(response)
      unless response.is_a?(Hash) && response['success'] != false
        raise APIError, 'Account search failed'
      end

      response
    end

    def posts_cursor_param_for(source:)
      case source.to_s
      when TIKTOK then 'max_cursor'
      when INSTAGRAM then 'next_max_id'
      when YOUTUBE then 'continuationToken'
      else 'cursor'
      end
    end

    def next_posts_cursor(res, source)
      return nil unless res.is_a?(Hash)

      cursor = case source.to_s
               when TIKTOK then res['max_cursor']
               when INSTAGRAM then res['next_max_id']
               when YOUTUBE then res['continuationToken'] || res['continuation_token']
               else res['cursor']
               end
      return nil if cursor.nil? || cursor.to_s.empty? || cursor.to_s == '0'

      cursor
    end

    def posts_has_more?(res, source, next_cursor)
      return false unless res.is_a?(Hash)

      if source.to_s == TIKTOK
        res['has_more'].to_i == 1
      else
        !next_cursor.nil?
      end
    end

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
