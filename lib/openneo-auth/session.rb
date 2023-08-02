require 'active_support/core_ext/hash'
require 'msgpack'
require 'openneo-auth-signatory'

module Openneo
  module Auth
    class Session
      REMOTE_MSG_KEYS = %w(session_id source user)
      TMP_STORAGE_DIR = Rails.root.join('tmp', 'openneo-auth-sessions')

      attr_writer :id

      def save!
        content = +MessagePack.pack(@message)
        FileUtils.mkdir_p TMP_STORAGE_DIR
        File.open(tmp_storage_path, 'w') do |file|
          file.write content
        end
      end

      def destroy!
        File.delete(tmp_storage_path)
      end

      def load_message!
        raise NotFound, "Session #{id} not found" unless File.exists?(tmp_storage_path)
        @message = File.open(tmp_storage_path, 'r') do |file|
          MessagePack.unpack file.read
        end
      end

      def params=(params)
        unless Auth.config.secret
          raise "Must set config.secret to the remote auth server's secret"
        end
        given_signature = params['signature']
        secret = +Auth.config.secret
        signatory = Auth::Signatory.new(secret)
        REMOTE_MSG_KEYS.each do |key|
          unless params.include?(key)
            raise MissingParam, "Missing required param #{key.inspect}"
          end
        end
        @message = params.slice(*REMOTE_MSG_KEYS)
        correct_signature = signatory.sign(@message)
        unless given_signature == correct_signature
          raise InvalidSignature, "Signature (#{given_signature}) " +
            "did not match message #{@message.inspect} (#{correct_signature})"
        end
      end

      def user
        Auth.config.find_user_with_remote_auth(@message['user'])
      end

      def self.from_params(params)
        session = new
        session.params = params
        session
      end

      def self.find(id)
        session = new
        session.id = id
        session.load_message!
        session
      end

      private

      def id
        @id ||= @message[:session_id]
      end

      def tmp_storage_path
        name = "#{id}.mpac"
        File.join TMP_STORAGE_DIR, name
      end

      class InvalidSession < ArgumentError;end
      class InvalidSignature < InvalidSession;end
      class MissingParam < InvalidSession;end
      class NotFound < StandardError;end
    end
  end
end

