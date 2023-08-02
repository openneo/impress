class Image
  attr_reader :insecure_url, :secure_url

  def initialize(insecure_url, secure_url)
    @insecure_url = insecure_url
    @secure_url = secure_url
  end

  def self.from_insecure_url(insecure_url)
    # TODO: We used to use a "Camo" server for this, but we don't anymore.
    # Replace this with actual logic to actually secure the URLs!
    Image.new insecure_url, insecure_url
  end
end
