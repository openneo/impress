require 'timeout'

module RocketAMF
  class RemoteGateway
    class Request
      ERROR_CODE = 'AMFPHP_RUNTIME_ERROR'
      
      def initialize(action, params)
        @action = action
        @params = params
      end
      
      def post(options={})
        uri = @action.service.gateway.uri
        data = envelope.serialize

        req = Net::HTTP::Post.new(uri.request_uri)
        req.body = data
        headers = options[:headers] || {}
        headers.each do |key, value|
          req[key] = value
        end
        
        res = nil
        
        if options[:timeout]
          Timeout.timeout(options[:timeout], ConnectionError) do
            res = send_request(uri, req)
          end
        else
          res = send_request(uri, req)
        end
        
        if res.is_a?(Net::HTTPSuccess)
          response_body = res.body
        else
          error = nil
          begin
            res.error!
          rescue Exception => scoped_error
            error = scoped_error
          end
          raise ConnectionError, error.message
        end
        
        begin
          result = RocketAMF::Envelope.new.populate_from_stream(response_body)
        rescue Exception => e
          raise ConnectionError, e.message, e.backtrace
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
        message.source = @action.service.name
        message.operation = @action.name
        message.body = @params
        message
      end
      
      def send_request(uri, req)
        begin
          http = Net::HTTP.new(uri.host, uri.port)
          return http.request(req)
        rescue Exception => e
          raise ConnectionError, e.message
        end
      end
    end
    
    class ConnectionError < RuntimeError
      def initialize(message)
        @message = message
      end
      
      def message
        "Error connecting to gateway: #{@message}"
      end
    end
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
