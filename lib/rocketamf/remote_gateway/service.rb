require File.join(File.dirname(__FILE__), 'action')

module RocketAMF
  class RemoteGateway
    class Service
      attr_reader :gateway, :name
      
      def initialize(gateway, name)
        @gateway = gateway
        @name = name
      end
      
      def action(name)
        Action.new(self, name)
      end
    end
  end
end
