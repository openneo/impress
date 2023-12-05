module FragmentLocalization
  def localize_fragment_key(key, locale)
    if key.is_a?(Hash)
      {:locale => locale}.merge(key)
    elsif key.is_a?(String)
      "#{key} #{locale}"
    else
      raise TypeError, "unexpected fragment key type: #{key.class}"
    end
  end
end
