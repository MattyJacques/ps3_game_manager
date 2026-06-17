module Library
  class Scanner
    class NasUnavailable < StandardError; end

    def initialize(nas_path: Rails.root.join("/nas"), extractor: TitleId::Extractor.new, catalog: nil, cover_cache: nil)
      @nas_path = Pathname(nas_path)
      @extractor = extractor
      @catalog = catalog
      @cover_cache = cover_cache || GameTdb::CoverCache.new
    end

    def call(scan:)
      raise NasUnavailable, "NAS share not mounted at #{nas_path}" unless nas_path.directory? && nas_path.readable?

      seen_paths = []
      errors = 0
      files_found = 0

      each_media_file.each_with_index do |path, offset|
        index = offset + 1
        files_found += 1
        seen_paths << path.to_s

        begin
          upsert_media_file!(path)
        rescue StandardError => error
          errors += 1
          Rails.logger.warn("scan failed for #{path}: #{error.message}")
        end

        yield(path.to_s, index) if block_given?
      end

      MediaFile.where.not(path: seen_paths).update_all(present: false)
      scan.complete!(files_found: files_found, errors_count: errors, summary: "Scanned #{files_found} files with #{errors} errors")
    end

    private

    attr_reader :nas_path, :extractor, :cover_cache

    def each_media_file
      Dir.glob(nas_path.join("**", "*").to_s, File::FNM_CASEFOLD).filter_map do |path|
        next unless File.file?(path)
        next unless %w[.iso .pkg].include?(File.extname(path).downcase)

        Pathname(path)
      end
    end

    def upsert_media_file!(path)
      now = Time.current
      title_id = extractor.call(path.to_s)
      media_file = MediaFile.find_or_initialize_by(path: path.to_s)

      media_file.assign_attributes(
        file_format: File.extname(path).delete(".").downcase,
        byte_size: path.size,
        title_id: title_id,
        present: true,
        first_seen_at: media_file.first_seen_at || now,
        last_seen_at: now
      )

      if title_id.present?
        entry = catalog.lookup(title_id)
        if entry
          game = Game.upsert_from_catalog!(title_id: title_id, entry: entry)
          attach_cover(game)
          media_file.game = game
        end
      end

      media_file.save!
    end

    def attach_cover(game)
      return if game.cover_path.present?

      cached_cover = cover_cache.fetch!(title_id: game.title_id, region: game.region)
      game.update!(cover_path: cached_cover.to_s) if cached_cover
    rescue StandardError => error
      Rails.logger.warn("cover fetch failed for #{game.title_id}: #{error.message}")
    end

    def catalog
      @catalog ||= GameTdb::Catalog.new
    rescue StandardError => error
      Rails.logger.warn("metadata lookup unavailable: #{error.message}")
      NullCatalog.new
    end

    class NullCatalog
      def lookup(_title_id)
        nil
      end
    end
  end
end
