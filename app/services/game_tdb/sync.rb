require "net/http"
require "zip"

module GameTdb
  class Sync
    def initialize(cache_dir: Rails.configuration.x.gametdb_cache_dir, archive_url: Rails.configuration.x.gametdb_archive_url, refresh_hours: Rails.configuration.x.gametdb_refresh_hours, fetcher: nil)
      @cache_dir = Pathname(cache_dir)
      @archive_url = archive_url
      @refresh_hours = refresh_hours
      @fetcher = fetcher || method(:default_fetch)
    end

    def ensure_current!
      FileUtils.mkdir_p(cache_dir)
      return xml_path if fresh?

      Zip::File.open_buffer(fetcher.call(URI.parse(archive_url))) do |zip_file|
        entry = zip_file.glob("ps3tdb.xml").first
        raise "ps3tdb.xml missing from archive" unless entry

        File.binwrite(xml_path, entry.get_input_stream.read)
      end

      xml_path
    rescue StandardError
      return xml_path if xml_path.exist?

      raise
    end

    private

    attr_reader :cache_dir, :archive_url, :refresh_hours, :fetcher

    def xml_path
      cache_dir.join("ps3tdb.xml")
    end

    def fresh?
      xml_path.exist? && xml_path.mtime > refresh_hours.hours.ago
    end

    def default_fetch(uri)
      Net::HTTP.get(uri)
    end
  end
end
