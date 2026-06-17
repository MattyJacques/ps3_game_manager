module TitleId
  class ParamSfo
    def call(bytes)
      raise ArgumentError, "invalid PARAM.SFO header" unless bytes.start_with?("\x00PSF")

      key_table_start = bytes[8, 4].unpack1("V")
      data_table_start = bytes[12, 4].unpack1("V")
      entry_count = bytes[16, 4].unpack1("V")

      entry_count.times.each_with_object({}) do |index, values|
        offset = 20 + (index * 16)
        key_offset, _format, value_length, _max_length, value_offset = bytes[offset, 16].unpack("vvVVV")

        key = bytes[(key_table_start + key_offset)..].split("\x00", 2).first
        raw_value = bytes[(data_table_start + value_offset), value_length]
        values[key] = raw_value.delete("\x00")
      end
    end
  end
end
