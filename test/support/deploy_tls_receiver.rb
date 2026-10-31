require "socket"
require "openssl"
require "json"
require "zlib"
require "stringio"

# Local ingestion fixture with an explicitly trusted, short-lived test certificate.
class DeployTLSReceiver
  attr_reader :url, :ca_path, :requests

  def initialize(root, status)
    @status = status
    @requests = []
    key = OpenSSL::PKey::RSA.new(2048)
    certificate = certificate_for(key)
    @ca_path = File.join(root, "ca.pem")
    File.write(@ca_path, certificate.to_pem)
    context = OpenSSL::SSL::SSLContext.new
    context.cert = certificate
    context.key = key
    @tcp = TCPServer.new("127.0.0.1", 0)
    @url = "https://127.0.0.1:#{@tcp.addr[1]}"
    @server = OpenSSL::SSL::SSLServer.new(@tcp, context)
    @thread = Thread.new { serve }
  end

  def stop
    @tcp.close unless @tcp.closed?
    @thread.kill
    @thread.join
  end

  private

  def certificate_for(key)
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = 1
    certificate.subject = OpenSSL::X509::Name.parse("/CN=localhost")
    certificate.issuer = certificate.subject
    certificate.public_key = key.public_key
    certificate.not_before = Time.now - 60
    certificate.not_after = Time.now + 3600
    factory = OpenSSL::X509::ExtensionFactory.new
    factory.subject_certificate = certificate
    factory.issuer_certificate = certificate
    certificate.add_extension(factory.create_extension("basicConstraints", "CA:TRUE", true))
    certificate.add_extension(factory.create_extension("subjectAltName", "IP:127.0.0.1"))
    certificate.sign(key, OpenSSL::Digest.new("SHA256"))
    certificate
  end

  def serve
    loop do
      client = @server.accept
      begin
        event = read_request(client)
        @requests << event
        sleep(1.2) if @status == :timeout
        body = @status == :receipt ? JSON.generate(receipt(event)) : "{}"
        status = [:receipt, :timeout].include?(@status) ? "202 Accepted" : @status
        client.write("HTTP/1.1 #{status}\r\nContent-Type: application/json\r\n" \
                     "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
      ensure
        client.close
      end
    end
  rescue IOError, Errno::EBADF, Errno::EPIPE, Errno::ECONNRESET, OpenSSL::SSL::SSLError
    nil
  end

  def read_request(client)
    client.gets
    headers = {}
    while (line = client.gets) && line != "\r\n"
      name, value = line.split(":", 2)
      headers[name.downcase] = value.strip
    end
    body = client.read(headers["content-length"].to_i)
    body = Zlib::GzipReader.new(StringIO.new(body)).read if headers["content-encoding"] == "gzip"
    JSON.parse(body)
  end

  def receipt(event)
    marker = event.fetch("context").fetch("integration_verification")
    {
      :schema_version => "1.0", :success => true, :status => "accepted",
      :verification_id => marker.fetch("verification_id"), :credentials_valid => true,
      :event_received => true, :event => {:id => event.fetch("event_id")},
      :project => {:id => "fixture", :name => "Fixture", :status => "active", :environment => "production"},
      :receiver => {:name => "fixture", :status => "operational", :received_at => Time.now.utc.to_s}, :error => nil
    }
  end
end
