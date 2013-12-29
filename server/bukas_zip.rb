#encoding:UTF-8
require 'rubygems'
require 'zip'
require 'open-uri'
require 'socket'
require 'logger'

# Ropencc
begin
  require 'ropencc'
  $use_tc2zc_convert = true
rescue LoadError => exception
  $use_tc2zc_convert = false
end


logger = Logger.new(ARGV[0] == "debug" ? STDOUT : 'log/bukas_zip.log')



module Zip
  class MyZipOutputStream
    include ::Zip::IOExtras::AbstractOutputStream

    attr_accessor :comment

    # Opens the indicated zip file. If a file with that name already
    # exists it will be overwritten.
    def initialize(fileName, stream)
      super()
      @fileName = fileName
      @output_stream = stream
      @entry_set = ::Zip::EntrySet.new
      @compressor = ::Zip::NullCompressor.instance
      @closed = false
      @current_entry = nil
      @comment = nil
      @buffer = ::StringIO.new
    end

    # Same as #initialize but if a block is passed the opened
    # stream is passed to the block and closed when the block
    # returns.
    class << self
      def open(fileName, stream)
        return new(fileName, stream) unless block_given?
        zos = new(fileName, stream)
        yield zos
      ensure
        zos.close if zos
      end
    end

    # Closes the stream and writes the central directory to the zip file
    def close
      return if @closed
      finalize_current_entry
      write_central_directory
      @buffer.close
      @closed = true
    end

    # Closes the current entry and opens a new for writing.
    # +entry+ can be a ZipEntry object or a string.
    def put_next_entry(entryname, comment = nil, extra = nil, compression_method = Entry::DEFLATED,  level = Zlib::DEFAULT_COMPRESSION)
      raise ZipError, "zip stream is closed" if @closed
      if entryname.kind_of?(Entry)
        new_entry = entryname
      else
        new_entry = Entry.new(@fileName, entryname.to_s)
      end
      new_entry.comment = comment if !comment.nil?
      if (!extra.nil?)
        new_entry.extra = ExtraField === extra ? extra : ExtraField.new(extra.to_s)
      end
      new_entry.compression_method = compression_method if !compression_method.nil?
      init_next_entry(new_entry, level)
      @current_entry = new_entry
    end

    private

    def finalize_current_entry
      return unless @current_entry
      finish
      @current_entry.compressed_size = @buffer.pos
      @current_entry.size = @compressor.size
      @current_entry.crc = @compressor.crc
      
      # force windows file type
      @current_entry.fstype = ::Zip::FSTYPE_FAT
      
      @current_entry.write_local_entry(@output_stream)
      @output_stream << @buffer.string
      @buffer.close
      @buffer = ::StringIO.new
      
      @current_entry = nil
      @compressor = NullCompressor.instance
    end

    def init_next_entry(entry, level = Zlib::DEFAULT_COMPRESSION)
      finalize_current_entry
      @entry_set << entry
      @compressor = get_compressor(entry, level)
    end

    def get_compressor(entry, level)
      case entry.compression_method
        when Entry::DEFLATED then Deflater.new(@buffer, level)
        when Entry::STORED   then PassThruCompressor.new(@buffer)
      else raise ZipCompressionMethodError,
        "Invalid compression method: '#{entry.compression_method}'"
      end
    end

    def write_central_directory
      cdir = CentralDirectory.new(@entry_set, @comment)
      cdir.write_to_stream(@output_stream)
    end

    protected

    def finish
      @compressor.finish
    end

    public
    # Modeled after IO.<<
    def << (data)
      @compressor << data
    end
  end
end





def get_file(uri)
  count = 1
  begin
    return open(uri) {|f| f.read}
  rescue
    return false if (count += 1) > 3
    retry
  end
end







class SocketWrapper
  def initialize(socket)
    @socket = socket
    @tell = 0
  end
  def tell
    return @tell
  end
  def << (data)
    @tell += @socket.write data
    @socket
  end
end

class ExitEarly < Exception
end








def handle_admin_socket(sock)
  sock.puts "welcome, admin!"
  notify_thread = nil
  loop do
    cmd = sock.gets.chomp
    if cmd == "down"
      $ready_to_down = true
      sock.puts "down!"
    elsif cmd == "up"
      $ready_to_down = false
      sock.puts "\\ up /"
    elsif cmd == "status"
      sock.puts $ready_to_down ? "down!" : "\\ up /"
    elsif cmd == "list"
      $download_clients.each { |client, downloading| sock.puts "%40s : %s" % [client, downloading]}
      sock.puts "========== finish =========="
    elsif cmd == "notify"
      if notify_thread and notify_thread.alive?
        sock.puts "already notifying!"
      else
        notify_thread = Thread.fork(sock) do |sock|
          loop do
            if $download_clients.empty?
              sock.puts "all downloads finished"
              break
            end
            sleep 1
          end
        end
        sock.puts "start notifying!"
      end
    else
      sock.puts "wrong command!"
    end
  end
  notify_thread.kill if notify_thread and notify_thread.alive?
end








def encode_str(str, force = "big5", conv = true)
  case force
  when "big5"
    str = Ropencc.conv(:simp_to_trad, str) if $use_tc2zc_convert and conv
    return str.encode("big5", {:invalid => :replace, :undef => :replace})
  when "gbk"
    str = Ropencc.conv(:trad_to_simp, str) if $use_tc2zc_convert and conv
    return str.encode("gbk", {:invalid => :replace, :undef => :replace})
  end
end



server = TCPServer.new('0.0.0.0', 34837)

index = File.open("bukas_zip_index.html", "r") {|f| f.read}
load("open_sesame.secret") # got secret !

logger.info "Server waiting..."

per_ip_cons = {}
tatal_cons = 0

MAX_PER_IP_CONS = 5
MAX_TOTAL_CONS = 50

$download_clients = {}


$ready_to_down = false


loop do

Thread.fork(server.accept) do |socket|

# plus cons
tatal_cons += 1
port, ip = Socket.unpack_sockaddr_in(socket.getpeername)
per_ip_cons[ip] = 0 unless per_ip_cons.has_key?(ip)
per_ip_cons[ip] += 1

begin
  
  # check max cons
  if tatal_cons > MAX_TOTAL_CONS or per_ip_cons[ip] > MAX_PER_IP_CONS or $ready_to_down
    request = socket.gets(128)
    if request.start_with?("GET / HTTP/1.")
      socket.print "HTTP/1.1 200 OK\r\n" +
                   "Content-Type: text/html\r\n" +
                   "Connection: close\r\n"
      socket.print "\r\n"
      socket.print index
    elsif request.start_with?("GET /robots.txt HTTP/1.")
      socket.print "HTTP/1.1 200 OK\r\n" +
                   "Content-Type: text/plain\r\n" +
                   "Connection: close\r\n"
      socket.print "\r\n"
      socket.print "User-agent: *\nDisallow: /"
    elsif request.start_with?("ADMIN") and ip == "127.0.0.1" # admin socket
      handle_admin_socket socket
    elsif request.start_with?("ADMIN")
      logger.fatal("#{ip} may try to hack admin?")
      socket.print "HTTP/1.1 501 Not Implemented\r\nConnection: close\r\n\r\n501 Not Implemented"
    else
      socket.print "HTTP/1.1 403 Forbidden\r\n" +
                   "Content-Type: text/html\r\n" +
                   "Connection: close\r\n"
      socket.print "\r\n"
      if $ready_to_down
        socket.print "本服務準備下線維修/更新<br\>暫時停止新下載連線<br\>請等待維修/更新結束，稍後再連線"
      elsif tatal_cons > MAX_TOTAL_CONS
        socket.print "Server is busy now - try again latter"
      else
        socket.print "You are downloading too many files simultaneously - Clam down!"
      end
    end
    raise ExitEarly.new
  end
  
  
  client_id = "#{ip}:#{port}-#{Time.now.to_i}"
  
  # Read the first line of the request (the Request-Line)
  request = socket.gets(4096) # avoid too long?
  raise ExitEarly.new unless request
  if request.start_with?("ADMIN") and ip == "127.0.0.1" # admin socket
    handle_admin_socket socket
    raise ExitEarly.new
  elsif request.start_with?("ADMIN")
    logger.fatal("#{ip} may try to hack admin?")
    socket.print "HTTP/1.1 501 Not Implemented\r\nConnection: close\r\n\r\n501 Not Implemented"
    raise ExitEarly.new
  end
  request = request.split(" ")
  
  raise ExitEarly.new if request.size < 3
  if !["GET"].include?(request[0]) or !request[2].start_with?("HTTP/1.")
    socket.print "HTTP/1.1 501 Not Implemented\r\nConnection: close\r\n\r\n501 Not Implemented"
    raise ExitEarly.new
  end
  request_uri = URI.parse(request[1])
  
  header = {}
  #while (hline = socket.gets) and !hline.empty? and hline != "\r\n"
  #  hline = hline.split(": ")
  #  hline[1][-2, 2] = ""
  #  header[hline[0].downcase.to_sym] = hline[1]
  #end
  
  post_data = ""
  #if request[0] == "POST"
  #  while !socket.eof? and (datline = socket.read)
  #    post_data += datline
  #  end
  #end
  
  
  ids = request_uri.path.split("/")
  
  if request_uri.path == "/robots.txt"
    socket.print "HTTP/1.1 200 OK\r\n" +
                 "Content-Type: text/plain\r\n" +
                 "Connection: close\r\n"
    socket.print "\r\n"
    socket.print "User-agent: *\nDisallow: /"
  elsif ids.empty?
    socket.print "HTTP/1.1 200 OK\r\n" +
                 "Content-Type: text/html\r\n" +
                 "Connection: close\r\n"
    socket.print "\r\n"
    socket.print index
  elsif (  ids.size == 4 or (ids.size == 5 and ids[3].start_with?("options!"))  ) and ids[2] == "book" # single_book
    # Ex: book_id/ep1!ep2!ep3!ep4
    
    # 以下URI分析
    id = ids[1].to_i
    idstr = id.to_s
    
    raise URI::InvalidURIError.new if id == 0
    
    list_mode = ids[3] == "list"
    
    # 分析書本頁 抓出各話ID & 對應分類(單行OR連載)
    type_list = {}
    ep_list = {}
    book_name = ""
    non_sort_count = non_sort_count_init = 9000
    open("http://#{$open_sesame_url}/bukas/#{id}/book", $open_sesame_auth) do |sesame|
      type_now = nil
      while (!sesame.eof?)
        line = sesame.readline
        if line =~ /<h1>(.+)<\/h1>/
          book_name = $1.chomp
        elsif line =~ /<h4 data-type="([0-9]+)">(.+)<\/h4>/
          type_now = $1.to_i
          type_list[type_now] = $2.chomp
          ep_list[type_now] = [] if list_mode
          non_sort_count = non_sort_count_init
        elsif line =~ /<a href="\/bukas\/([0-9]+)\/view\/\?cid=([0-9]+)"><input type="checkbox" class="check_me" value="([0-9]+)" \/>(.+)<\/a>/
          ep = $2.to_i
          if type_now.nil? || $1 != idstr || $2 != $3
            raise OpenURI::HTTPError.new("format err", nil)
          else
            if list_mode
              ep_list[type_now].push [ep, $4.chomp]
            else
              sort_val = type_now * 10000 # base - type
              ep_name = $4.chomp
              if ep_name =~ /^\d+$/ # just digits
                sort_val += ep_name.to_i
              else
                sort_val += non_sort_count
                non_sort_count -= 1
              end
              ep_list[ep] = [type_now, ep_name, sort_val]
            end
          end
        end
      end
      raise OpenURI::HTTPError.new("format err", nil) if type_list.empty? || ep_list.empty?
    end
    
    if list_mode
      ####
      
      socket.print "HTTP/1.1 200 OK\r\n" +
                   "Content-Type: text/plain; charset=\"utf-8\"\r\n" +
                   "Connection: close\r\n"
      socket.print "\r\n"
      type_list.each do |type_id, type_name|
        socket.print "type!#{type_id}!#{type_name}\n"
        for i in ep_list[type_id].reverse
          socket.print "ep!#{i[0]}!#{i[1]}\n"
        end
      end
      
      
    else
      ####
      
      
      
      # 分析URL - 下載清單
      has_options = ids[3].start_with?("options!")
      fn_encoding = "big5"
      use_conv = true
      if has_options
        options = ids[3][8...ids[3].length].split("!")
        for opt in options
          fn_encoding = opt[15...opt.length] if opt.start_with?("force_encoding:")
          use_conv = false if opt == "no_conversion"
        end
      end
      
      eps = []
      
      eps = has_options ? ids[4] : ids[3]
      eps = eps[2...eps.length] if eps.start_with?("1:")  # compatible to opensesame wrong format - wait to be fix and remove this
      eps = eps.split("!")
      eps.each_with_index { |val, idx| eps[idx] = val.to_i }
      # sort
      eps.sort! { |a, b| ep_list[a][2] <=> ep_list[b][2] }
      
      # 抓出所有圖片
      file_list = []
      for ep in eps
        raise URI::InvalidURIError.new if not ep_list.has_key?(ep)
        
        open("http://#{$open_sesame_url}/bukas/#{id}/view/?cid=#{ep}", $open_sesame_auth) do |sesame|
          while (!sesame.eof?)
            line = sesame.readline
            file_list.push ["#{type_list[ep_list[ep][0]]}/#{ep_list[ep][1]}/#{$2}", "#{$1}/#{$2}", "#{id}-#{ep}", ep] if line =~ /<span><img data-src="(.+)\/(.+)"><\/span><br\/>/
          end
          raise OpenURI::HTTPError.new("format err", nil) if file_list.empty?
        end
      end
      
      
      fn = "book-#{book_name}_#{id}_#{rand(10000)}.zip"
      
      
      
      # ready to download - add record
      $download_clients[client_id] = fn
      
      
      
      socket.print "HTTP/1.1 200 OK\r\n" +
                   "Content-Type: application/octet-stream\r\n" +
                   "Content-Disposition: attachment; filename=\"#{fn}\";\r\n" +
                   "Connection: close\r\n"
      socket.print "\r\n"
      
      read_to_down_check = 0
      
      zos = Zip::MyZipOutputStream.open(fn, SocketWrapper.new(socket))
      for i in file_list
        fc = get_file(i[1])
        logger.info "#{client_id} - Saving file - #{i[2]} - #{i[0]}"
        if $ready_to_down
          if read_to_down_check != i[3] # ep changed! - time to abort
            zos.put_next_entry(encode_str("下線維修中，請稍後再繼續下載(中斷處為最後下載中的一話or集)"))
            zos.puts "下線維修中，請稍後再繼續下載(中斷處為最後下載中的一話or集)"
            break
          else # my fault - server file (!?
            zos.put_next_entry(encode_str(i[0], fn_encoding, use_conv))
            zos.puts fc
          end
        elsif fc
          zos.put_next_entry(encode_str(i[0], fn_encoding, use_conv))
          zos.puts fc
        else
          zos.put_next_entry("Something Wrong!!!")
          zos.puts "Something Wrong!!!"
          break
        end
        # set after processed
        read_to_down_check = i[3]
      end
      zos.close
      logger.info "#{client_id} - Download finished!"
      
      
    end
    
    
    
  elsif ids.size == 3 # 單話
    id1 = ids[1].to_i
    id2 = ids[2].to_i
    
    raise URI::InvalidURIError.new if id1 == 0 || id2 == 0
    
    ####
    file_list = []
    book_name = ""
    open("http://#{$open_sesame_url}/bukas/#{id1}/view/?cid=#{id2}", $open_sesame_auth) do |sesame|
      while (!sesame.eof?)
        line = sesame.readline
        file_list.push [$2, "#{$1}/#{$2}"] if line =~ /<span><img data-src="(.+)\/(.+)"><\/span><br\/>/
        book_name = $1.chomp if line =~ /<h1>(.+)<\/h1>/
      end
      raise OpenURI::HTTPError.new("format err", nil) if file_list.empty?
    end
    
    
    
    
    fn = "book-#{book_name}_ep_#{id1}_#{id2}.zip"
    
    
    # ready to download - add record
    $download_clients[client_id] = fn
    
    
    socket.print "HTTP/1.1 200 OK\r\n" +
                 "Content-Type: application/octet-stream\r\n" +
                 "Content-Disposition: attachment; filename=\"#{fn}\";\r\n" +
                 "Connection: close\r\n"
    socket.print "\r\n"
    
    zos = Zip::MyZipOutputStream.open(fn, SocketWrapper.new(socket))
    for i in file_list
      fc = get_file(i[1])
      logger.info "#{client_id} - Saving file - #{id1}-#{id2} - #{i[0]}"
      # ignore ready_to_down here - just wait it over (since there only a few files)
      if fc
        zos.put_next_entry(i[0])
        zos.puts fc
      else
        zos.put_next_entry("Something Wrong!!!")
        zos.puts "Something Wrong!!!"
        break
      end
    end
    zos.close
    logger.info "#{client_id} - Download finished!"
    
    
  else
    raise URI::InvalidURIError.new
  end
  
rescue URI::InvalidURIError => exception
  socket.print "HTTP/1.1 403 Forbidden\r\n" +
               "Content-Type: text/html\r\n" +
               "Connection: close\r\n"
  socket.print "\r\n"
  socket.print "Frobidden - Invaild URI"
rescue OpenURI::HTTPError => exception
  socket.print "HTTP/1.1 502 Bad Gateway\r\n" +
               "Content-Type: text/html\r\n" +
               "Connection: close\r\n"
  socket.print "\r\n"
  socket.print "Bad Gateway - Maybe you entered wrong id pair or something strange happened to OpenSesame"
  
  logger.error request_uri
rescue ExitEarly
  # just exit early OwO
rescue => exception
  socket.print "HTTP/1.1 500 Internal Server Error\r\n" +
               "Content-Type: text/html\r\n" +
               "Connection: close\r\n"
  socket.print "\r\n"
  socket.print "Internal Server Error - Please report to admin"
  
  logger.error exception.inspect
  logger.error exception.backtrace
  logger.error request_uri
ensure
  socket.close if socket and !socket.closed?
  # minus cons
  tatal_cons -= 1
  per_ip_cons[ip] -= 1
  per_ip_cons.delete(ip) if per_ip_cons[ip] == 0
  
  # remove downloading record
  $download_clients.delete(client_id) if $download_clients.has_key?(client_id)
  
end


end # Thread.fork

end

