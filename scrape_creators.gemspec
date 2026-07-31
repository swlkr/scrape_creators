# frozen_string_literal: true

require_relative "lib/scrape_creators/version"

Gem::Specification.new do |spec|
  spec.name          = "scrape_creators"
  spec.version       = ScrapeCreators::VERSION
  spec.authors       = ["swlkr"]
  spec.summary       = "Zero-dependency Ruby client for Scrape Creators API"
  spec.description   = "Ruby client for Scrape Creators API (https://scrapecreators.com) to fetch social media profile, posts, reels, and comments."
  spec.homepage      = "https://github.com/swlkr/scrape_creators"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files         = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]
end
