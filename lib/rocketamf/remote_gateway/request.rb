module RocketAMF
  class RemoteGateway
    class Request
      ERROR_CODE = 'AMFPHP_RUNTIME_ERROR'
      
      def initialize(service, method, *params)
        @service = service
        @method = method
        @params = params
      end
      
      def fetch
        uri = @service.gateway.uri
        data = envelope.serialize
        if EventMachine.reactor_running?
          req = EM::HttpRequest.new(uri).post :body => data
          response_body = req.response
        else
          req = Net::HTTP::Post.new(uri.path)
          req.body = data
          res = Net::HTTP.new(uri.host, uri.port).start { |http| http.request(req) }
          case res
          when Net::HTTPSuccess
            response_body = res.body
          else
            error = nil
            begin
              res.error!
            rescue Exception => scoped_error
              error = scoped_error
            end
            raise ConnectionError, "Error connecting to gateway: #{error}"
          end
        end
        begin
          result = RocketAMF::Envelope.new.populate_from_stream(response_body)
        rescue Exception => e
          raise ConnectionError, "Error parsing gateway response: #{e.message}"
        end
        first_message_data = result.messages[0].data
        if first_message_data.respond_to?(:[]) && first_message_data[:code] == ERROR_CODE
          raise AMFError.new(first_message_data)
        end
        result
      end
      
      private
      
      def envelope
        output = Envelope.new
        output.messages << wrapper_message
        output
      end
      
      def wrapper_message
        message = Message.new 'null', '/1', [remoting_message]
      end
      
      def remoting_message
        message = Values::RemotingMessage.new
        message.source = @service.name
        message.operation = @method
        message.body = @params
        message
      end
    end
    
    class ConnectionError < RuntimeError;end
    class AMFError < RuntimeError
      DATA_KEYS = [:details, :line, :code]
      attr_reader *DATA_KEYS
      attr_reader :message
      
      def initialize(data)
        DATA_KEYS.each do |key|
          instance_variable_set "@#{key}", data[key]
        end
        
        @message = data[:description]
      end
    end
  end
end
