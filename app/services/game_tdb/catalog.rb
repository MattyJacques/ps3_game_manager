require "nokogiri"

module GameTdb
  class Catalog
    def initialize(xml_path: Sync.new.ensure_current!)
      @xml_path = xml_path
    end

    def lookup(title_id)
      game = document.at_xpath("//game[id='#{title_id}']")
      game && extract_entry(game)
    end

    def search(query, limit: 20)
      needle = query.to_s.downcase
      return [] if needle.blank?

      document.xpath("//game").filter_map do |game|
        entry = extract_entry(game)
        entry if entry.fetch(:name).downcase.include?(needle)
      end.first(limit)
    end

    private

    attr_reader :xml_path

    def document
      @document ||= Nokogiri::XML(File.read(xml_path))
    end

    def extract_entry(game)
      title_id = game.at_xpath("id").text

      {
        title_id: title_id,
        name: game.at_xpath("locale/title")&.text.presence || game["name"],
        region: game.at_xpath("region")&.text.presence || region_from_title_id(title_id),
        kind: game.at_xpath("type")&.text.to_s.downcase == "psn" ? "psn" : "disc"
      }
    end

    def region_from_title_id(title_id)
      case title_id
      when /\A(BLUS|BCUS|NPUB|NPUA)/ then "US"
      when /\A(BLES|BCES|NPEB|NPEA)/ then "EU"
      when /\A(BLJM|BCJS|NPJB|NPJA)/ then "JP"
      else "EN"
      end
    end
  end
end
