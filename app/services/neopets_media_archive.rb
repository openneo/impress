require "addressable/uri"
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
  ROOT_PATH = Pathname.new(Rails.configuration.neopets_media_archive_root)

  # Load the file from the given `images.neopets.com` URI.
  # Set `refresh: true` to skip the local copy and re-download from the origin,
  # overwriting it. (We use this when a cached file turns out to be corrupt.)
  def self.load_file(uri, return_content: true, refresh: false)
    local_path = local_file_path(uri)

    # Read the file locally if we have it. We treat an empty file as if it
    # weren't there: a 0-byte file is the fingerprint of a past failed download
    # (e.g. a transient empty response from the origin), and because we only
    # used to check existence, such failures got cached forever. Ignoring empty
    # files lets them self-heal on the next request.
    if refresh
      debug "Refreshing file from origin: #{local_path}"
    elsif return_content
      begin
        content = File.binread(local_path)
        if content.empty?
          debug "Ignoring empty cached file, will re-download: #{local_path}"
        else
          debug "Loaded source file from filesystem: #{local_path}"
          return {content: content, source: "filesystem"}
        end
      rescue Errno::ENOENT
        # If it doesn't exist, that's fine: just move on and download it.
      end
    else
      # When we don't need the content, "loading" the file is just ensuring
      # it exists. If it doesn't, we'll move on and load it from source.
      # (We use this when preloading files, to save the cost of reading files
      # we're not ready to use yet.)
      if File.exist?(local_path) && File.size(local_path) > 0
        debug "Source file is already loaded, skipping: #{local_path}"
        return {content: nil, source: "filesystem"}
      end
    end

    # Download the file from the origin, then save a copy for next time.
    content = load_file_from_origin(uri)
    info "Loaded source file from origin: #{uri}"

    # Don't cache empty responses: that's how we got stuck with 0-byte files in
    # the first place. Leave it unsaved so a future request can retry.
    if content.nil? || content.empty?
      warn "Got empty response for #{uri}; not caching it"
      return {content: return_content ? content : nil, source: "network"}
    end

    write_file_atomically(local_path, content)
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
      DTIRequests.get(uri) do |response|
        if response.status != 200
          raise ResponseNotOK.new(response.status),
            "expected status 200 but got #{response.status} (#{uri})"
        end

        # If the connection drops mid-body, we can get a clean-looking prefix of
        # the file, which we'd then cache forever. So when the origin declares a
        # length (async-http exposes Content-Length as `body.length`, not as a
        # header), make sure we got all of it.
        expected_length = response.body&.length
        content = response.read
        actual_length = content&.bytesize || 0
        if expected_length && actual_length != expected_length
          raise IncompleteResponse,
            "expected #{expected_length} bytes but got #{actual_length} (#{uri})"
        end

        content
      end
    end
  end

  # Write to a temporary file in the same directory, then rename it into place.
  # The rename is atomic, so readers see either the old file or the complete
  # new one, never a partial write, and a crash mid-write can't leave a
  # truncated file behind.
  #
  # We write in binary mode: content is often a binary file (e.g. a PNG), and
  # `File.write`'s default text mode would try to transcode it to UTF-8, fail on
  # the first non-UTF-8 byte, and leave a truncated 0-byte file behind.
  def self.write_file_atomically(local_path, content)
    local_path.dirname.mkpath
    temp_path = local_path.dirname +
      ".#{local_path.basename}.#{Process.pid}.#{SecureRandom.hex(4)}.tmp"
    begin
      File.binwrite(temp_path, content)
      File.rename(temp_path, local_path)
    ensure
      File.delete(temp_path) if File.exist?(temp_path)
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

  # The origin's response body was shorter (or longer) than its declared
  # Content-Length, e.g. because the connection dropped. Likely intermittent.
  class IncompleteResponse < StandardError; end

  private

  def self.info(message)
    Rails.logger.info "[NeopetsMediaArchive] #{message}"
  end

  def self.debug(message)
    Rails.logger.debug "[NeopetsMediaArchive] #{message}"
  end

  def self.warn(message)
    Rails.logger.warn "[NeopetsMediaArchive] #{message}"
  end
end
