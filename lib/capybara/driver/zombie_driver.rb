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
      native_call(".value = #{value.to_s.inspect}")
    end

    private

    def native_call(call)
      socket_read "pointers[#{@native}]#{call}"
    end

    def socket_read(js)
      @driver.send(:socket_read, js)
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
browser.visit(#{url(path).to_s.inspect}, function(error){
  if(error)
    stream.end(error.stack);
  else
    stream.end();
});
    JS

    raise ZombieError, response unless response.empty?
  end

  def response_headers
    Headers.new socket_json("browser.lastResponse.headers")
  end

  def status_code
    socket_json "browser.lastResponse.status"
  end

  def body
    socket_read "browser.html()"
  end

  def current_url
    socket_read "browser.location.toString()"
  end

  def find(selector)
    ids = socket_send <<-JS
var sets = [];
browser.xpath(#{selector.to_s.inspect}).value.forEach(function(node){
  pointers.push(node);
  sets.push(pointers.length - 1);
});
stream.end(sets.join(","));
    JS

    ids.split(",").map { |n| Node.new(self, n) }
  end

  private

  def socket_send(js)
    socket = socket_open
    socket.write js
    socket.read.tap { socket.close }
  end

  def socket_read(js)
    socket_send "stream.end(#{js});"
  end

  def socket_json(js)
    MultiJson.decode(socket_read("JSON.stringify(#{js})"))
  end

  def socket_open
    TCPSocket.open("127.0.0.1", 8124)
  end

  def url(path)
    rack_server.url(path)
  end
end

Capybara.register_driver :zombie do |app|
  Capybara::Driver::Zombie.new(app)
end
