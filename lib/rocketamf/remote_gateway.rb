require 'net/http'
require 'rocketamf'
require File.join(File.dirname(__FILE__), 'remote_gateway', 'service')
require File.join(File.dirname(__FILE__), 'remote_gateway', 'request')

module RocketAMF
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

