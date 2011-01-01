require "socket"

class Capybara::Driver::Zombie < Capybara::Driver::Base
  class Node < Capybara::Driver::Node
    def visible?
      native_call(".style.display") !~ /none/
    end

    def [](name)
      name = name.to_s
      name = "className" if name == "class"
      native_call("[#{name.to_s.inspect}]")
    end

    def text
      native_call(".textContent")
    end

    def tag_name
      native_call(".tagName").downcase
    end

    def value
      native_call(".value")
    end

    def set(value)
      native_call(".value = #{encode(value)}")
    end

    private

    def native_call(call)
      socket_json "pointers[#{@native}]#{call}"
    end

    def encode(value)
      @driver.send(:encode, value)
    end

    def socket_json(js)
      @driver.send(:socket_json, js)
    end
  end

  class Headers
    def initialize(hash)
      @hash = hash
    end

    def [](key)
      pair = @hash.find { |pair| pair[0].downcase == key.downcase }
      # TODO We should not check this, we need to fix capybara tests
      pair && (pair[0] == "content-type" ? pair[1].split(";")[0] : pair[1])
    end
  end

  class ZombieError < ::StandardError
  end

  attr_reader :app, :rack_server, :options

  def initialize(app, options={})
    @app = app
    @options = options
    @rack_server = Capybara::Server.new(@app)
    @rack_server.boot if Capybara.run_server
  end

  def visit(path)
    response = socket_send <<-JS
browser.visit(#{encode(url(path))}, function(error){
  if(error)
    stream.end(JSON.stringify(error.stack));
  else
    stream.end();
});
    JS

    raise ZombieError, decode(response) unless response.empty?
  end

  def response_headers
    Headers.new socket_json("browser.lastResponse.headers")
  end

  def status_code
    socket_json "browser.lastResponse.status"
  end

  def body
    socket_json "browser.html()"
  end

  def current_url
    socket_json "browser.location.toString()"
  end

  def evaluate_script(script)
    socket_json script
  end

  def find(selector)
    ids = socket_send <<-JS
var sets = [];
browser.xpath(#{encode(selector.to_s)}).value.forEach(function(node){
  pointers.push(node);
  sets.push(pointers.length - 1);
});
stream.end(JSON.stringify(sets));
    JS

    decode(ids).map { |n| Node.new(self, n) }
  end

  private

  def encode(value)
    MultiJson.encode(value)
  end

  def decode(value)
    MultiJson.decode(value)
  end

  def socket_send(js)
    socket = TCPSocket.open("127.0.0.1", 8124)
    socket.write(js)
    socket.close_write
    socket.read.tap { socket.close_read }
  end

  def socket_json(js)
    decode(socket_send("stream.end(JSON.stringify(#{js}));"))
  end

  def url(path)
    rack_server.url(path)
  end
end

Capybara.register_driver :zombie do |app|
  Capybara::Driver::Zombie.new(app)
end
