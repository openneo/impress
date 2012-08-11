module RocketAMF
  class RemoteGateway
    class Service
      attr_reader :gateway, :name
      
      def initialize(gateway, name)
        @gateway = gateway
        @name = name
      end
      
      def request(method, *params)
        Request.new(self, method, *params)
      end
    end
  end
end
