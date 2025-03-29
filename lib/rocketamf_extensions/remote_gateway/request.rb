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
        
        # HACK: It seems to me that these messages come back with Windows-1250
        # (or similar) encoding on the strings? I'm basing this on the
        # Patchwork Staff item, whose description arrives as:
        #
        # "That staff is cute, but dont use it as a walking stick \x96 I " +
        # "dont think it will hold you up!"
        #
        # And the `\x96` is meant to represent an endash, which it doesn't in
        # UTF-8 or in most extended ASCII encodings, but *does* in Windows's
        # specific extended ASCII.
        #
        # Idk if this is something to do with the AMFPHP spec or how the AMFPHP
        # server code they use serializes strings (I couldn't find any
        # reference to it?), or just their internal database encoding being
        # passed along as-is, or what? But this seems to be the most correct
        # interpretation I know how to do, so, let's do it!
        result.messages[0].data.body.tap do |body|
          reencode_strings! body, "Windows-1250", "UTF-8"
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

      def reencode_strings!(target, from, to)
        if target.is_a? String
          target.force_encoding(from).encode!(to)
        elsif target.is_a? Array
          target.each { |x| reencode_strings!(x, from, to) }
        elsif target.is_a? Hash
          target.values.each { |x| reencode_strings!(x, from, to) }
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
