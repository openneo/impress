require 'net/http'
require 'rocketamf'
require_relative 'remote_gateway/service'

module RocketAMFExtensions
  class RemoteGateway
    attr_reader :uri

    def initialize(url)
      @uri = URI.parse url
    end

    def service(name)
      Service.new(self, name)
    end
  end
end

