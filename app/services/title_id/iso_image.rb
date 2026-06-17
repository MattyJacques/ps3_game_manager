module TitleId
  class IsoImage
    SECTOR_SIZE = 2048

    def initialize(param_sfo: ParamSfo.new)
      @param_sfo = param_sfo
    end

    def call(path)
      File.open(path, "rb") do |io|
        directory = read_directory(io, root_record(io))
        ps3_game = directory.fetch("PS3_GAME")
        ps3_directory = read_directory(io, ps3_game)
        param_sfo_record = ps3_directory.fetch("PARAM.SFO")

        io.seek(param_sfo_record[:extent] * SECTOR_SIZE)
        @param_sfo.call(io.read(param_sfo_record[:size]))
      end
    end

    private

    def root_record(io)
      io.seek(16 * SECTOR_SIZE)
      sector = io.read(SECTOR_SIZE)
      raise ArgumentError, "invalid ISO9660 header" unless sector[1, 5] == "CD001"

      parse_record(sector[156, 34])
    end

    def read_directory(io, record)
      io.seek(record[:extent] * SECTOR_SIZE)
      data = io.read(record[:size])
      entries = {}
      cursor = 0

      while cursor < data.bytesize
        length = data.getbyte(cursor)
        break if length.nil? || length.zero?

        entry = parse_record(data[cursor, length])
        cursor += length

        next if [ "", ".", ".." ].include?(entry[:name])

        entries[entry[:name]] = entry
      end

      entries
    end

    def parse_record(bytes)
      extent = bytes[2, 4].unpack1("V")
      size = bytes[10, 4].unpack1("V")
      name_length = bytes.getbyte(32)
      name = bytes[33, name_length]
      normalized_name =
        case name
        when "\x00" then "."
        when "\x01" then ".."
        else name.delete("\x00").sub(/;1\z/, "")
        end

      { extent: extent, size: size, name: normalized_name }
    end
  end
end
