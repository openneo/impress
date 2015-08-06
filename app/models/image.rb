class Image
  attr_reader :insecure_url, :secure_url

  def initialize(insecure_url, secure_url)
    @insecure_url = insecure_url
    @secure_url = secure_url
  end

  def self.from_insecure_url(insecure_url)
    Image.new insecure_url, proxy_insecure_url(insecure_url)
  end

  private

  def self.proxy_insecure_url(insecure_url)
    if CAMO_HOST && CAMO_KEY
      hexdigest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), CAMO_KEY, insecure_url)
      uri = Addressable::URI.parse("#{CAMO_HOST}/#{hexdigest}")
      uri.query_values = { url: insecure_url }
      uri.to_s
    else
      uri = Addressable::URI.parse(insecure_url)
      query_values = uri.query_values || {}
      uri.query_values = query_values.merge(NO_CAMO_CONFIG: nil)
      uri.to_s
    end
  end
end
