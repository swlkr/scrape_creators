# frozen_string_literal: true

require_relative "scrape_creators/version"
require_relative "scrape_creators/error"
require_relative "scrape_creators/configuration"
require_relative "scrape_creators/client"

module ScrapeCreators
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configuration=(config)
      @configuration = config
    end

    def configure
      yield(configuration)
    end

    def reset
      @configuration = Configuration.new
    end
  end
end
