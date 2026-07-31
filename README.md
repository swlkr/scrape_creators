# ScrapeCreators

A zero-dependency Ruby client for the [Scrape Creators API](https://docs.scrapecreators.com).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'scrape_creators', '0.1.0'
```

And then execute:

```bash
$ bundle install
```

## Configuration

Configure your API key in an initializer (e.g., `config/initializers/scrape_creators.rb`):

```ruby
ScrapeCreators.configure do |config|
  config.api_key = ENV['SCRAPE_CREATORS_API_KEY']
end
```

## Usage

Initialize a client:

```ruby
scraper = ScrapeCreators::Client.new
```

### Fetch Instagram User Posts & Reels

```ruby
posts = scraper.posts("zuck")
```

### Fetch Instagram Post / Reel Info

```ruby
info = scraper.post("https://www.instagram.com/p/DKSMEpKRd6h/", download_media: true)
```

### Fetch Instagram Post / Reel Comments

```ruby
comments = scraper.comments("https://www.instagram.com/p/DKSMEpKRd6h/")
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
