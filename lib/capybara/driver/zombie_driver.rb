require "capybara/zombie/helpers"

class Capybara::Driver::Zombie < Capybara::Driver::Base
  include Capybara::Zombie::Helpers

  class Node < Capybara::Driver::Node
    include Capybara::Zombie::Helpers

    def visible?
      native_json(".style.display").to_s !~ /none/
    end

    def [](name)
      name = name.to_s
      name = "className" if name == "class"
      native_json("[#{name.to_s.inspect}]")
    end

    def text
      native_json(".textContent")
    end

    def tag_name
      native_json(".tagName").downcase
    end

    def value
      native_json(".value")
    end

    def set(value)
      native_json(".value = #{encode(value)}")
    end

    def select_option
      native_json(".selected = true")
    end

    def unselect_option
      unless self['multiple']
        raise Capybara::UnselectNotAllowed, "Cannot unselect option from single select box."
      end
      native_json(".removeAttribute('selected')")
    end

    def click
      browser_wait :fire, "click".inspect, native_ref
    end

    private

    def native_json(call)
      socket_json "#{native_ref}#{call}"
    end

    def native_ref
      "pointers[#{@native}]"
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

  attr_reader :app, :rack_server, :options

  def initialize(app, options={})
    @app = app
    @options = options
    @rack_server = Capybara::Server.new(@app)
    @rack_server.boot if Capybara.run_server
  end

  def visit(path)
    browser_wait(:visit, encode(url(path)))
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

  # TODO Is this really correct?
  def source
    socket_json "browser.document.outerHTML"
  end

  def current_url
    socket_json "browser.location.toString()"
  end

  def evaluate_script(script)
    socket_json script
  end

  def find(selector, context=nil)
    ids = socket_send <<-JS
var sets = [];
browser.xpath(#{encode(selector)}).value.forEach(function(node){
  pointers.push(node);
  sets.push(pointers.length - 1);
});
stream.end(JSON.stringify(sets));
    JS

    decode(ids).map { |n| Node.new(self, n) }
  end

  private

  def url(path)
    rack_server.url(path)
  end
end

Capybara.register_driver :zombie do |app|
  Capybara::Driver::Zombie.new(app)
end
