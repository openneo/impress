require_relative 'action'

module RocketAMFExtensions
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
