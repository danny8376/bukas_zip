require 'ffi'

module Jpeg
  extend FFI::Library

  ffi_lib 'libjpeg'

  class JPEGCompressStruct < FFI::Struct
    # forever TODO construct this struct
    # Wait, wait, and wait, and ......
    #layout :width, :int
  end

  class << self
  end
end

