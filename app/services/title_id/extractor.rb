module TitleId
  class Extractor
    SERIAL_REGEX = /([A-Z]{4}\d{5})/

    def initialize(pkg_header: PkgHeader.new)
      @pkg_header = pkg_header
    end

    def call(path)
      filename_match(path) || pkg_match(path)
    end

    private

    attr_reader :pkg_header

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
  end
end
