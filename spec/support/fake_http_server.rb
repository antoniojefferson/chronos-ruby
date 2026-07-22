require "socket"

class FakeHttpServer
  attr_reader :request_line, :request_headers, :request_body

  def initialize(status, options = {})
    @status = status
    @headers = options[:headers] || {}
    @response_body = options[:body] || "{}"
    @response_builder = options[:response_builder]
    @delay = options[:delay] || 0
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve }
  end

  def url(scheme = "http")
    "#{scheme}://127.0.0.1:#{@port}"
  end

  def stop
    @server.close
  rescue IOError, Errno::EBADF
    nil
  ensure
    @thread.join(0.5) if @thread
    @thread.kill if @thread && @thread.alive?
  end

  private

  def serve
    client = @server.accept
    @request_line = client.gets
    @request_headers = {}
    while (line = client.gets)
      break if line == "\r\n"
      key, value = line.split(":", 2)
      @request_headers[key.downcase] = value.to_s.strip
    end
    length = @request_headers["content-length"].to_i
    @request_body = client.read(length) if length > 0
    @response_body = @response_builder.call(@request_body, @request_headers) if @response_builder
    sleep(@delay)
    write_response(client)
  rescue IOError, Errno::EBADF, Errno::ECONNRESET, Errno::EPIPE
    nil
  ensure
    client.close if client && !client.closed?
    @server.close unless @server.closed?
  end

  def write_response(client)
    response_headers = {
      "Content-Type" => "application/json",
      "Content-Length" => @response_body.bytesize.to_s,
      "Connection" => "close"
    }.merge(@headers)
    client.write("HTTP/1.1 #{@status}\r\n")
    response_headers.each do |response_key, response_value|
      client.write("#{response_key}: #{response_value}\r\n")
    end
    client.write("\r\n#{@response_body}")
  end
end
