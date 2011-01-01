require "socket"

module Capybara
  class ZombieError < ::StandardError
  end

  module Zombie
    module Helpers
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

      def browser_wait(method, *args)
        response = socket_send <<-JS
browser.#{method}(#{args.join(", ")}, function(error){
  if(error)
    stream.end(JSON.stringify(error.stack));
  else
    stream.end();
});
        JS

        raise ZombieError, decode(response) unless response.empty?
      end
    end
  end
end