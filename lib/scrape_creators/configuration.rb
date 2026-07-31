# frozen_string_literal: true

module ScrapeCreators
  class Configuration
    attr_accessor :api_key, :api_base_url, :open_timeout, :read_timeout

    def initialize
      @api_key = ENV['SCRAPE_CREATORS_API_KEY']
      @api_base_url = "https://api.scrapecreators.com"
      @open_timeout = 10
      @read_timeout = 30
    end
  end
end
