module TitleId
  class PkgHeader
    CONTENT_ID_REGEX = /[A-Z]{2}\d{4}-([A-Z]{4}\d{5})_/

    def call(path)
      bytes = File.binread(path, 512)
      match = bytes.match(CONTENT_ID_REGEX)
      match && match[1]
    end
  end
end
