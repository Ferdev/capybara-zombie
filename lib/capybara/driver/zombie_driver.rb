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

      result = socket_send <<-JS
if(#{native_ref}.tagName.toLowerCase() == "select" && #{name.to_s == "value"} && #{native_ref}["multiple"]) {
  var selected = [];
  var options = #{native_ref}.options;
  for(var i = 0; i < #{native_ref}.length; i++)
    if(options[i].selected)
      selected.push(options[i].value);
  stream.end(JSON.stringify(selected));
} else {
  stream.end(JSON.stringify(#{native_ref}[#{name.to_s.inspect}]));
}
      JS

      decode(result)
    end

    def text
      native_json(".textContent")
    end

    def tag_name
      native_json(".tagName").downcase
    end

    def value
      if tag_name == 'textarea'
        text
      else
        self[:value]
      end
    end

    def set(value)
      socket_write <<-JS
if(#{native_ref}.tagName == "TEXTAREA") {
  #{native_ref}.textContent = #{encode(value)};
} else if(#{native_ref}.getAttribute("type") == "checkbox" || #{native_ref}.getAttribute("type") == "radio") {
  if(#{native_ref}.checked != #{encode(value)}) #{native_ref}.click();
} else {
  #{native_ref}.value = #{encode(value)};
}
      JS
    end

    def find(selector)
      @driver.find(selector, native_ref)
    end

    def select_option
      socket_write <<-JS
browser.selectOption(browser.xpath("./ancestor::select", #{native_ref}).value[0], #{native_ref})
      JS
    end

    def unselect_option
      unless select_node['multiple']
        raise Capybara::UnselectNotAllowed, "Cannot unselect option from single select box."
      end

      socket_write "#{native_ref}.removeAttribute('selected')"
    end

    def click
      browser_wait :fire, "click".inspect, native_ref
    end

    private

    def select_node
      find('./ancestor::select').first
    end

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
    args = [encode(selector), context].compact.join(",")

    ids = socket_send <<-JS
var sets = [];
browser.xpath(#{args}).value.forEach(function(node){
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
