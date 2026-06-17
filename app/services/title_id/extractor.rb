module TitleId
  class Extractor
    SERIAL_REGEX = /([A-Z]{4}\d{5})/

    def initialize(pkg_header: PkgHeader.new, iso_image: IsoImage.new)
      @pkg_header = pkg_header
      @iso_image = iso_image
    end

    def call(path)
      filename_match(path) || pkg_match(path) || iso_match(path)
    end

    private

    attr_reader :pkg_header, :iso_image

    def filename_match(path)
      [File.basename(path), File.basename(File.dirname(path))].each do |candidate|
        match = candidate.match(SERIAL_REGEX)
        return match[1] if match
      end

      nil
    end

    def pkg_match(path)
      return unless File.extname(path).casecmp(".pkg").zero?

      pkg_header.call(path)
    end

    def iso_match(path)
      return unless File.extname(path).casecmp(".iso").zero?

      iso_image.call(path).fetch("TITLE_ID", nil)
    rescue KeyError, ArgumentError
      nil
    end
  end
end
