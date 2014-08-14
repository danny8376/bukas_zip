require 'ffi'

module WebP
  extend FFI::Library

  ffi_lib FFI::Library::LIBC
  ffi_lib 'libwebp'

  class WebPBitstreamFeatures < FFI::Struct
    layout :width, :int,
           :height, :int,
           :has_alpha, :int
  end

  attach_function :free, [:pointer], :void

  attach_function :WebPGetInfo, [:pointer, :size_t, :pointer, :pointer], :int
  #attach_function :WebPGetFeatures, [:pointer, :size_t, :pointer], :int
  attach_function :WebPGetFeaturesInternal, [:pointer, :size_t, :pointer, :int], :int

  class << self
    def get_info dat
      wp, hp = FFI::MemoryPointer.new(:int), FFI::MemoryPointer.new(:int)
      status = WebPGetInfo dat, dat.size, wp, hp
      w, h = (wp.read_bytes(wp.size) + hp.read_bytes(hp.size)).unpack('i*')
      wp.free
      hp.free
      status == 0 ? [-1, status] : [w, h]
    end

    # Borken?
    def get_features dat
      features = WebPBitstreamFeatures.new
      #WebPGetFeatures dat, dat.size, features.to_ptr
      WebPGetFeaturesInternal dat, dat.size, features.to_ptr, 0x0002
      w, h, ha = features[:width], features[:height], features[:has_alpha]
      features.to_ptr.free
      [w, h, ha]
    end
  end

  # decode XXXs
  [:RGBA, :ARGB, :BGRA, :RGB, :BGR].each do |t|
    ps = t.to_s.size
    self.instance_eval "
      attach_function :WebPDecode#{t}, [:pointer, :size_t, :pointer, :pointer], :pointer
      def decode#{t} dat, unpack = false
        wp, hp = FFI::MemoryPointer.new(:int), FFI::MemoryPointer.new(:int)
        samples_buf = WebPDecode#{t} dat, dat.size, wp, hp
        w, h = (wp.read_bytes(wp.size) + hp.read_bytes(hp.size)).unpack('i*')
        return [w, h, unpack ? [] : ''] if w == 0 or h == 0 or samples_buf.null?
        samples = samples_buf.read_bytes(w * h * #{ps})
        samples = samples.unpack('C*') if unpack
        wp.free
        hp.free
        #samples_buf.free
        free samples_buf
        [w, h, samples]
      end

      attach_function :WebPDecode#{t}Into, [:pointer, :size_t, :pointer, :int, :int], :pointer
      def bufferedDecode#{t} dat, unpack = false
        w, h = get_info dat
        return [w, h, unpack ? [] : ''] if w == 0 or h == 0
        buf = FFI::MemoryPointer.new(:uint8, w * h * #{ps})
        res = WebPDecode#{t}Into dat, dat.size, buf, w * h * #{ps}, w * #{ps}
        return [w, h, unpack ? [] : ''] if res.null?
        samples = buf.read_bytes(w * h * #{ps})
        buf.free
        samples = samples.unpack('C*') if unpack
        [w, h, samples]
      end
    "
  end
end

