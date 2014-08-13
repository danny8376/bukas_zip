require 'zlib'

module PNG
  class << self
    # data => RGBA array
    def encodePNG(w, h, data)
      buf = make_png_header
      buf += make_png_ihdr(w, h)
      buf += make_png_idat(w, h, data)
      buf += make_png_iend
      buf
    end

    def make_png_header
      [0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a].pack("C*")
    end

    def make_png_ihdr(w, h)
      ih_size = [13].pack("N")
      string = ["IHDR", w, h,    8    ,     6     ,         0         ,
      #          sign , w, h,bit depth, color type, compression method,
                0    ,        0        ].pack("A*NNCCCCC")
      # filter method, interlace method
      ih_crc = [Zlib.crc32(string)].pack("N")
      ih_size + string + ih_crc
    end

    def make_png_idat(w, h, dat)
      header = "\x49\x44\x41\x54"
      data = make_png_data(w, h, dat)
      data = Zlib::Deflate.deflate(data, 8)
      crc = [Zlib.crc32(header + data)].pack("N")
      size = [data.length].pack("N")
      size + header + data + crc
    end

    def make_png_data(w, h, data)
      for y in 0...h
        nth = (h - 1 - y) * w * 4
        data.insert(nth,"\000")
      end
      data
    end

    def make_png_iend
      ie_size = [0].pack("N")
      ie_sign = "IEND"
      ie_crc = [Zlib.crc32(ie_sign)].pack("N")
      ie_size + ie_sign + ie_crc
    end
  end
end
