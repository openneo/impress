module RocketAMF
  class RemoteGateway
    class Service
      attr_reader :gateway, :name
      
      def initialize(gateway, name)
        @gateway = gateway
        @name = name
      end
      
      def fetch(method, *params)
        Request.new(self, method, *params).fetch
      end
    end
  end
end
