require 'ffi'

module WebP
  extend FFI::Library

  ffi_lib 'libwebp'

  class WebPBitstreamFeatures < FFI::Struct
    layout :width, :int,
           :height, :int,
           :has_alpha, :int
  end

  attach_function :WebPGetInfo, [:pointer, :size_t, :pointer, :pointer], :int
  #attach_function :WebPGetFeatures, [:pointer, :uint32, :pointer], :int
  attach_function :WebPGetFeaturesInternal, [:pointer, :uint32, :pointer, :int], :int

  class << self
    def get_info dat
      wp, hp = FFI::MemoryPointer.new(:int), FFI::MemoryPointer.new(:int)
      status = WebPGetInfo dat, dat.size, wp, hp
      w, h = (wp.read_bytes(wp.size) + hp.read_bytes(hp.size)).unpack('i*')
      wp.free
      hp.free
      status == 0 ? [0, 0] : [w, h]
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
    self.instance_eval "
      attach_function :WebPDecode#{t}, [:pointer, :uint32, :pointer, :pointer], :pointer
      def decode#{t} dat
        wp, hp = FFI::MemoryPointer.new(:int), FFI::MemoryPointer.new(:int)
        samples_buf = WebPDecode#{t} dat, dat.size, wp, hp
        w, h = (wp.read_bytes(wp.size) + hp.read_bytes(hp.size)).unpack('i*')
        samples = samples_buf.read_bytes(w * h * #{t.to_s.size}).unpack('C*')
        wp.free
        hp.free
        samples_buf.free
        [w, h, samples]
      end
    "
  end
end

