module PrettyParam
  BLACKLIST = /[^a-z0-9]/i
  def name_for_param
    name.split(BLACKLIST).select { |word| !word.blank? }.join('-')
  end

  def to_param
    "#{id}-#{name_for_param}"
  end
end

