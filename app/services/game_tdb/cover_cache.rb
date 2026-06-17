require "net/http"

module GameTdb
  class CoverCache
    def initialize(cache_dir: Rails.configuration.x.cover_cache_dir, fetcher: nil)
      @cache_dir = Pathname(cache_dir)
      @fetcher = fetcher || method(:default_fetch)
    end

    def fetch!(title_id:, region:)
      FileUtils.mkdir_p(cache_dir)
      destination = cache_dir.join("#{title_id}.jpg")
      return destination if destination.exist?

      bytes = fetcher.call(URI.parse("https://art.gametdb.com/ps3/cover/#{region}/#{title_id}.jpg"))
      File.binwrite(destination, bytes)
      destination
    end

    private

    attr_reader :cache_dir, :fetcher

    def default_fetch(uri)
      Net::HTTP.get(uri)
    end
  end
end
