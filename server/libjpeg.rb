require 'ffi'

module JPEG
  extend FFI::Library

  ffi_lib FFI::Library::LIBC
  ffi_lib 'libjpeg'

  JPEG_LIB_VERSION = 80

  DCTSIZE = 8
  DCTSIZE2 = 64
  NUM_QUANT_TBLS = 4
  NUM_HUFF_TBLS = 4
  NUM_ARITH_TBLS = 16
  MAX_COMPS_IN_SCAN = 4
  MAX_SAMP_FACTOR = 4
  C_MAX_BLOCKS_IN_MCU = 10

  JMSG_STR_PARM_MAX = 80

  J_COLOR_SPACE = enum [
    :JCS_UNKNOWN,
    :JCS_GRAYSCALE,
    :JCS_RGB,
    :JCS_YCbCr,
    :JCS_CMYK,
    :JCS_YCCK
  ]

  J_DCT_METHOD = enum [
    :JDCT_ISLOW,
    :JDCT_IFAST,
    :JDCT_FLOAT
  ]

  class MsgParmUnion < FFI::Union
    layout :i, [:int, 8],
           :s, [:char, JMSG_STR_PARM_MAX]
  end

  class JPEGErrorMgr < FFI::Struct
    #callback :error_exit_func, [JPEGCommonStruct.ptr], :void
    #callback :emit_message_func, [JPEGCommonStruct.ptr, :int], :void
    #callback :output_message_func, [JPEGCommonStruct.ptr], :void
    #callback :format_message_func, [JPEGCommonStruct.ptr, :string], :void
    #callback :reset_error_mgr_func, [JPEGCommonStruct.ptr], :void

    layout :error_exit, :pointer,
           :emit_message, :pointer,
           :output_message, :pointer,
           :format_message, :pointer,
           :reset_error_mgr, :pointer,

           :msg_code, :int,
           :msg_parm, MsgParmUnion,

           :trace_level, :int,

           :num_warnings, :long,

           :jpeg_message_table, :pointer, # const char * const *
           :last_jpeg_message, :int,

           :addon_message_table, :pointer, # const char * const *
           :first_addon_message, :int,
           :last_addon_message, :int
  end

  #class JQUANT_TBL < FFI::Struct
  #  layout :quantval, [:uint16, DCTSIZE2],
  #         :sent_table, :int
  #end

  #class JHUFF_TBL < FFI::Struct
  #  layout :bits, [:uint8, 17],
  #         :huffval, [:uint8, 256],
  #         :sent_table, :int
  #end

  class JPEGCommonStruct < FFI::Struct
    layout :err, :pointer, #JPEGErrorMgr.ptr,
           :mem, :pointer, #JPEGMemoryMgr.ptr,
           :progress, :pointer, #JPEGProgressMgr.ptr,
           :client_data, :pointer, # void *
           :is_decompressor, :int,
           :global_state, :int
  end

  class JPEGCompressStruct < FFI::Struct
    layout :err, :pointer, #JPEGErrorMgr.ptr,
           :mem, :pointer, #JPEGMemoryMgr.ptr,
           :progress, :pointer, #JPEGProgressMgr.ptr,
           :client_data, :pointer, # void *
           :is_decompressor, :int,
           :global_state, :int,

           :dest, :pointer, #JPEGDestinationMgr.ptr
           :image_width, :uint,
           :image_height, :uint,
           :input_components, :int,
           :in_color_space, J_COLOR_SPACE,

           :input_gamma, :double,
           :scale_denom, :uint,
           :scale_num, :uint,

           :jpeg_width, :uint,
           :jpeg_height, :uint,

           :data_precision, :int,

           :num_components, :int,
           :jpeg_color_space, J_COLOR_SPACE,

           :comp_info, :pointer, #JPEGComponentInfo.ptr,

           :quant_tbl_ptrs, [:pointer, NUM_QUANT_TBLS], #[JQUANT_TBL.ptr, NUM_QUANT_TBLS],
           :q_scale_factor, [:int, NUM_QUANT_TBLS],

           :dc_huff_tbl_ptrs, [:pointer, NUM_HUFF_TBLS], #[JHUFF_TBL.ptr, NUM_HUFF_TBLS],
           :ac_huff_tbl_ptrs, [:pointer, NUM_HUFF_TBLS], #[JHUFF_TBL.ptr, NUM_HUFF_TBLS],

           :arith_dc_L, [:uint8, NUM_ARITH_TBLS],
           :arith_dc_U, [:uint8, NUM_ARITH_TBLS],
           :arith_ac_K, [:uint8, NUM_ARITH_TBLS],

           :num_scans, :int,
           :scan_info, :pointer, #JPEGScanInfo.ptr,

           :raw_data_in, :int,
           :arith_code, :int,
           :optimize_coding, :int,
           :CCIR601_sampling, :int,
           :do_fancy_downsampling, :int,
           :smoothing_factor, :int,
           :dct_method, J_DCT_METHOD,

           :restart_interval, :uint,
           :restart_in_rows, :int,

           :write_JFIF_header, :int,
           :JFIF_major_version, :uint8,
           :JFIF_minor_version, :uint8,
           :density_unit, :uint8,
           :X_density, :uint16,
           :Y_density, :uint16,
           :write_Adobe_marker, :int,
  
           :next_scanline, :uint,

           :progressive_mode, :int,
           :max_h_samp_factor, :int,
           :max_v_samp_factor, :int,

           :min_DCT_h_scaled_size, :int,
           :min_DCT_v_scaled_size, :int,

           :total_iMCU_rows, :uint,
           :comps_in_scan, :int,
           :cur_comp_info, [:pointer, MAX_COMPS_IN_SCAN], #[JPEGComponentInfo.ptr, MAX_COMPS_IN_SCAN],
  
           :MCUs_per_row, :uint,
           :MCU_rows_in_scan, :uint,

           :blocks_in_MCU, :int,
           :MCU_membership, [:int, C_MAX_BLOCKS_IN_MCU],

           :Al, :int,
           :Ss, :int,
           :Se, :int,
           :Ah, :int,

           :block_size, :int,
           :natural_order, :pointer, # int *
           :lim_Se, :int,
  
           :master, :pointer, #JPEGCompMaster.ptr,
           :main, :pointer, #JPEGCMainController.ptr,
           :prep, :pointer, #JPEGCPrepController.ptr,
           :coef, :pointer, #JPEGCCoefController.ptr,
           :marker, :pointer, #JPEGMarkerWriter.ptr,
           :cconvert, :pointer, #JPEGColorConverter.ptr,
           :downsample, :pointer, #JPEGDownsampler.ptr,
           :fdct, :pointer, #JPEGForwardCct.ptr,
           :entropy, :pointer, #JPEGEntropyEncoder.ptr,
           :script_space, :pointer, #JPEGScanInfo.ptr,
           :script_space_size, :int
  end

  attach_function :free, [:pointer], :void

  attach_function :jpeg_std_error, [JPEGErrorMgr.ptr], JPEGErrorMgr.ptr
  attach_function :jpeg_CreateCompress, [JPEGCompressStruct.ptr, :int, :size_t], :void
  attach_function :jpeg_mem_dest, [JPEGCompressStruct.ptr, :pointer, :pointer], :void
  attach_function :jpeg_set_defaults, [JPEGCompressStruct.ptr], :void
  attach_function :jpeg_set_quality, [JPEGCompressStruct.ptr, :int, :int], :void
  attach_function :jpeg_start_compress, [JPEGCompressStruct.ptr, :int], :void
  attach_function :jpeg_write_scanlines, [JPEGCompressStruct.ptr, :pointer, :uint], :uint
  attach_function :jpeg_finish_compress, [JPEGCompressStruct.ptr], :void
  attach_function :jpeg_destroy_compress, [JPEGCompressStruct.ptr], :void

  class << self
    def jpeg_create_compress cinfo
      jpeg_CreateCompress cinfo, JPEG_LIB_VERSION, JPEGCompressStruct.size
    end

    def encodeJPEG w, h, dat
      cinfo = JPEGCompressStruct.new

      jerr = JPEGErrorMgr.new
      cinfo[:err] = jpeg_std_error jerr

      jpeg_create_compress cinfo

      dest_ptr = FFI::MemoryPointer.new :pointer
      dest_size = FFI::MemoryPointer.new :long
      jpeg_mem_dest cinfo, dest_ptr, dest_size

      cinfo[:image_width] = w
      cinfo[:image_height] = h
      cinfo[:input_components] = 3
      cinfo[:in_color_space] = J_COLOR_SPACE[:JCS_RGB]

      jpeg_set_defaults cinfo
      jpeg_set_quality cinfo, 80, 1

      jpeg_start_compress cinfo, 1

      src_samples = FFI::MemoryPointer.from_string dat
      src_samples_rows = FFI::MemoryPointer.new :pointer, h
      h.times { |ln| src_samples_rows.put_pointer ln * FFI::Pointer::SIZE, src_samples.slice(ln * w * 3, w * 3) }

      jpeg_write_scanlines cinfo, src_samples_rows, h

      src_samples.free
      src_samples_rows.free

      jpeg_finish_compress cinfo
      jpeg_destroy_compress cinfo

      size = dest_size.read_bytes(dest_size.size).unpack('L')[0]
      dest = dest_ptr.read_pointer
      dest_ptr.free
      dest_size.free

      out = dest.read_bytes size
      free dest

      out
    end
  end
end

