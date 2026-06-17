require "test_helper"

class TitleIdIsoImageTest < ActiveSupport::TestCase
  test "reads TITLE_ID from PARAM.SFO inside an ISO" do
    Dir.mktmpdir do |dir|
      iso_path = File.join(dir, "generic.iso")
      File.binwrite(iso_path, build_test_iso(build_param_sfo("TITLE_ID" => "BLUS30490", "TITLE" => "God of War III")))

      extractor = TitleId::Extractor.new
      assert_equal "BLUS30490", extractor.call(iso_path)
    end
  end

  private

  def build_param_sfo(values)
    keys = +""
    data = +""
    entries = values.map do |key, value|
      key_offset = keys.bytesize
      data_offset = data.bytesize

      keys << key << "\x00"
      data << value << "\x00"

      [ key_offset, 0x0204, value.bytesize + 1, value.bytesize + 1, data_offset ].pack("vvVVV")
    end.join

    key_table_start = 20 + entries.bytesize
    data_table_start = key_table_start + keys.bytesize

    [ "\x00PSF", [ 0x00000101, key_table_start, data_table_start, values.size ].pack("VVVV"), entries, keys, data ].join
  end

  def build_test_iso(param_sfo_bytes)
    sectors = Array.new(24) { "\x00" * 2048 }
    primary_volume = "\x00" * 2048
    primary_volume.setbyte(0, 1)
    primary_volume[1, 5] = "CD001"
    primary_volume.setbyte(6, 1)
    primary_volume[156, 34] = directory_record(20, 2048, "\x00")
    sectors[16] = primary_volume

    root_directory = +""
    root_directory << directory_record(20, 2048, "\x00")
    root_directory << directory_record(20, 2048, "\x01")
    root_directory << directory_record(21, 2048, "PS3_GAME")
    sectors[20] = root_directory.ljust(2048, "\x00")

    ps3_directory = +""
    ps3_directory << directory_record(21, 2048, "\x00")
    ps3_directory << directory_record(20, 2048, "\x01")
    ps3_directory << directory_record(22, param_sfo_bytes.bytesize, "PARAM.SFO;1")
    sectors[21] = ps3_directory.ljust(2048, "\x00")

    sectors[22] = param_sfo_bytes.ljust(2048, "\x00")
    sectors.join
  end

  def directory_record(extent, size, name)
    name_bytes = name.b
    padding = name_bytes.bytesize.even? ? 1 : 0
    length = 33 + name_bytes.bytesize + padding
    record = [ length, 0, extent, extent, size, size ].pack("CCVVVV")
    record << ("\x00" * 7)
    record << [ 0, 0, 0, 1, 1 ].pack("CCCvv")
    record << [ name_bytes.bytesize ].pack("C")
    record << name_bytes
    record << "\x00" if record.bytesize.odd?
    record.ljust(length, "\x00")
  end
end
