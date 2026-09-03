# ScrapeCreators

A zero-dependency Ruby client for the [Scrape Creators API](https://docs.scrapecreators.com).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'scrape_creators', '0.6.0'
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

### Fetch TikTok Profile Videos

```ruby
posts = scraper.posts("zuck", source: 'tiktok')
```

### Fetch YouTube Channel Shorts

```ruby
posts = scraper.posts("zuck", source: 'youtube')
```

### Cursor-based pagination

All three platforms support cursor-based pagination. By default `posts` returns the first page only. Pass `pages:` to fetch more (e.g. `5` for the first five pages of a creator's feed):

```ruby
posts = scraper.posts("zuck", pages: 5)                    # Instagram
posts = scraper.posts("zuck", source: 'tiktok', pages: 5)   # TikTok
posts = scraper.posts("zuck", source: 'youtube', pages: 5) # YouTube Shorts
```

If you need finer control, `posts_page` returns `{ items:, cursor:, has_more: }` so you can page through the full timeline yourself:

```ruby
page = scraper.posts_page("zuck", source: 'tiktok')
loop do
  page[:items].each { |item| puts item['desc'] }
  break unless page[:has_more] && page[:cursor]
  page = scraper.posts_page("zuck", source: 'tiktok', cursor: page[:cursor])
end
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
