require 'timeout'

module RocketAMFExtensions
  class RemoteGateway
    class Request
      ERROR_CODE = 'AMFPHP_RUNTIME_ERROR'
      
      def initialize(action, params)
        @action = action
        @params = params
      end
      
      def post(options={})
        response_body = if options[:timeout]
          Timeout.timeout(options[:timeout], ConnectionError) do
            send_request(options)
          end
        else
          send_request(options)
        end
        
        begin
          result = RocketAMF::Envelope.new.populate_from_stream(response_body)
        rescue Exception => e
          raise ConnectionError, e.message, e.backtrace
        end
        
        first_message_data = HashWithIndifferentAccess.new(result.messages[0].data)
        if first_message_data.respond_to?(:[]) && first_message_data[:code] == ERROR_CODE
          raise RocketAMF::AMFError.new(first_message_data)
        end
        
        # HACK: Older items in Neopets' database have Windows-1250 encoding,
        # while newer items use proper UTF-8. We detect which encoding was used
        # by checking if the string is valid UTF-8, and only re-encode if needed.
        #
        # Example of Windows-1250 item: Patchwork Staff (57311), whose
        # description contains byte 0x96 (en-dash in Windows-1250).
        #
        # Example of UTF-8 item: Carnival Party Décor (80042), whose name
        # contains proper UTF-8 bytes [195, 169] for the é character.
        result.messages[0].data.body.tap do |body|
          reencode_strings_if_needed! body, "Windows-1250", "UTF-8"
        end
      end
      
      private
      
      def envelope
        output = RocketAMF::Envelope.new
        output.messages << wrapper_message
        output
      end
      
      def wrapper_message
        message = RocketAMF::Message.new 'null', '/1', [remoting_message]
      end
      
      def remoting_message
        message = RocketAMF::Values::RemotingMessage.new
        message.source = @action.service.name
        message.operation = @action.name
        message.body = @params
        message
      end
      
      def send_request(options={})
        url = @action.service.gateway.uri
        headers = options.fetch(:headers, []).to_a
        body = envelope.serialize

        begin
          Sync do
            DTIRequests.post(url, headers, body) do |response|
              if response.status != 200
                raise ConnectionError,
                  "expected status 200 but got #{response.status} (#{url})"
              end

              response.read
            end
          end
        rescue Exception => e
          raise ConnectionError, e.message
        end
      end

      def reencode_strings_if_needed!(target, from, to)
        if target.is_a? String
          # Only re-encode if the string is not valid UTF-8
          # (indicating it's in the old Windows-1250 encoding)
          unless target.valid_encoding?
            target.force_encoding(from).encode!(to)
          end
        elsif target.is_a? Array
          target.each { |x| reencode_strings_if_needed!(x, from, to) }
        elsif target.is_a? Hash
          target.values.each { |x| reencode_strings_if_needed!(x, from, to) }
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
