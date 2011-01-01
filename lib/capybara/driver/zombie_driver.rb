require "socket"

class Capybara::Driver::Zombie < Capybara::Driver::Base
  class Node < Capybara::Driver::Node
    def visible?
      native_call(".style.display") !~ /none/
    end

    private

    def native_call(call)
      socket_read "stream.end(pointers[#{@native}]#{call});"
    end

    def socket_read(js)
      @driver.send(:socket_read, js)
    end
  end

  attr_reader :app, :rack_server, :options

  def initialize(app, options={})
    @app = app
    @options = options
    @rack_server = Capybara::Server.new(@app)
    @rack_server.boot if Capybara.run_server
  end

  def visit(path)
    socket_read <<-JS
browser.visit(#{url(path).to_s.inspect});
browser.wait(function(){
  stream.end();
});
    JS
  end

  def current_url
    socket_read "stream.end(browser.location.toString());"
  end

  def find(selector)
    ids = socket_read <<-JS
var sets = [];
browser.xpath(#{selector.to_s.inspect}).value.forEach(function(node){
  pointers.push(node);
  sets.push(pointers.length - 1);
});
stream.end(sets.join(","));
    JS

    ids.split(",").map do |n|
      Node.new(self, n)
    end
  end

  private

  def socket_read(js)
    socket = socket_open
    socket.write js
    socket.read.tap { socket.close }
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
