require "socket"

module Capybara
  module Zombie
    class NodeError < ::StandardError
    end

    module Helpers
      def encode(value)
        MultiJson.encode(value)
      end

      def decode(value)
        MultiJson.decode(value)
      end

      # Send something to the socket, you are responsible to close the stream.
      def socket_send(js)
        socket = TCPSocket.open("127.0.0.1", 8124)
        socket.write(js)
        socket.close_write
        socket.read.tap { socket.close_read }
      end

      # Send something to the socket, but do not care about return value.
      def socket_write(js)
        socket_send("#{js}\nstream.end();")
      end

      # Send something to the socket which is automatically converted from/to JSON.
      def socket_json(js)
        decode(socket_send("stream.end(JSON.stringify(#{js}));"))
      end

      # Send something to the browser and automatically set a callback function
      # with error handling.
      def browser_wait(method, *args)
        response = socket_send <<-JS
browser.#{method}(#{args.join(", ")}, function(error){
  if(error)
    stream.end(JSON.stringify(error.stack));
  else
    stream.end();
});
        JS

        raise NodeError, decode(response) unless response.empty?
      end
    end
  end
end