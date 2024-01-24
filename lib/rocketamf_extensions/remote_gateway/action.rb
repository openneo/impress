require_relative 'request'

module RocketAMFExtensions
  class RemoteGateway
    class Action
      attr_reader :service, :name
      
      def initialize(service, name)
        @service = service
        @name = name
      end
      
      def request(params)
        Request.new(self, params)
      end
    end
  end
end
