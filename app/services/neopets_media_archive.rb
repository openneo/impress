require "addressable/uri"
require "async/http/internet/instance"
require "json"

# The Neopets Media Archive is a service that mirrors images.neopets.com files
# locally. You can request a file from it, and we'll serve it from disk if we
# have it, or request and save it if not.
#
# This is a bit different than a cache, because the intention is not just
# optimization but that we *want* to be saving images.neopets.com as a
# long-term archive, not dependent on their services having 100% uptime in
# order for us to operate. We never discard old files, we just keep going!
module NeopetsMediaArchive
  # Share a pool of persistent connections, rather than reconnecting on
  # each request. (This library does that automatically!)
  INTERNET = Async::HTTP::Internet.instance

  ROOT_PATH = Pathname.new(Rails.configuration.neopets_media_archive_root)

  # Load the file from the given `images.neopets.com` URI.
  def self.load_file(uri, return_content: true)
    local_path = local_file_path(uri)

    # Read the file locally if we have it.
    if return_content
      begin
        content = File.read(local_path)
        debug "Loaded source file from filesystem: #{local_path}"
        return {content: content, source: "filesystem"}
      rescue Errno::ENOENT
        # If it doesn't exist, that's fine: just move on and download it.
      end
    else
      # When we don't need the content, "loading" the file is just ensuring
      # it exists. If it doesn't, we'll move on and load it from source.
      # (We use this when preloading files, to save the cost of reading files
      # we're not ready to use yet.)
      if File.exist?(local_path)
        debug "Source file is already loaded, skipping: #{local_path}"
        return {content: nil, source: "filesystem"}
      end
    end

    # Download the file from the origin, then save a copy for next time.
    content = load_file_from_origin(uri)
    info "Loaded source file from origin: #{uri}"
    local_path.dirname.mkpath
    File.write(local_path, content)
    info "Wrote source file to filesystem: #{local_path}"
    
    {content: return_content ? content : nil, source: "network"}
  end

  # Load the file from the given `images.neopets.com` URI, but don't return its
  # content. This can be faster in cases where the file's content isn't
  # relevant to us, and we just want to ensure it exists.
  def self.preload_file(uri)
    load_file(uri, return_content: false)
  end

  # Load the file from the given `images.neopets.com` URI, directly from the
  # source, without checking the local filesystem.
  def self.load_file_from_origin(uri)
    unless Addressable::URI.parse(uri).origin == "https://images.neopets.com"
      raise ArgumentError, "NeopetsMediaArchive can only load from " +
        "https://images.neopets.com, but got #{uri}"
    end

    # By running this request in a `Sync` block, we make this method look
    # synchronous to the caller—but if run in the context of an async task, it
    # will pause execution and move onto other work until the request is done.
    # We use this in the `swf_assets:manifests:load` task to perform many
    # requests in parallel!
    Sync do
      INTERNET.get(uri, [
        ["User-Agent", Rails.configuration.user_agent_for_neopets],
      ]) do |response|
        if response.status != 200
          raise ResponseNotOK.new(response.status),
            "expected status 200 but got #{response.status} (#{uri})"
        end
        response.read
      end
    end
  end

  def self.path_within_archive(uri)
    uri = Addressable::URI.parse(uri)
    path = uri.host + uri.path

    # We include the query string as part of the file path, which is a bit odd!
    # But Neopets often uses this for cache-busting, so we do need a mechanism
    # for knowing whether we're holding the right version of the file. We could
    # also consider storing the file by just its normal path, but with some
    # metadata to track versioning information (e.g. a sqlite db, or a metadata
    # file in the same directory).
    path += "?" + uri.query if !uri.query.nil? && !uri.query.empty?

    path
  end

  def self.local_file_path(uri)
    ROOT_PATH + path_within_archive(uri)
  end

  class ResponseNotOK < StandardError
    attr_reader :status
    def initialize(status)
      super
      @status = status
    end
  end

  private

  def self.info(message)
    Rails.logger.info "[NeopetsMediaArchive] #{message}"
  end

  def self.debug(message)
    Rails.logger.debug "[NeopetsMediaArchive] #{message}"
  end
end
