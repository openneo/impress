module LocaleMeta
  PUBLIC_LOCALES = []
  USABLE_LOCALES = []
  NEOPETS_LANGUAGE_CODES_BY_LOCALE = {}
  LOCALES_WITH_NEOPETS_LANGUAGE_CODE = []
  COMPATIBLE_LOCALES = {}
end

config = YAML.load_file(Rails.root.join('config', 'locale_meta.yml'))

config.each do |locale_str, locale_meta|
  locale = locale_str.to_sym
  
  visibility = locale_meta['visibility']
  if visibility == 'public'
    LocaleMeta::PUBLIC_LOCALES << locale
    LocaleMeta::USABLE_LOCALES << locale
  elsif visibility == 'private'
    LocaleMeta::USABLE_LOCALES << locale
  end
  
  if locale_meta.has_key?('neopets_language_code')
    neopets_language_code = locale_meta['neopets_language_code']
    LocaleMeta::NEOPETS_LANGUAGE_CODES_BY_LOCALE[locale] = neopets_language_code
    LocaleMeta::LOCALES_WITH_NEOPETS_LANGUAGE_CODE << locale
  elsif locale_meta.has_key?('compatible_with')
    compatible_locale = locale_meta['compatible_with'].to_sym
    LocaleMeta::COMPATIBLE_LOCALES[locale] = compatible_locale
  else
    raise "locale #{locale} must either have a neopets_language_code or " +
      "be compatible_with a locale that does"
  end
end

module I18n
  def self.public_locales
    LocaleMeta::PUBLIC_LOCALES
  end
  
  def self.usable_locales
    LocaleMeta::USABLE_LOCALES
  end
  
  def self.locales_with_neopets_language_code
    LocaleMeta::LOCALES_WITH_NEOPETS_LANGUAGE_CODE
  end
  
  def self.neopets_language_code_for(locale)
    LocaleMeta::NEOPETS_LANGUAGE_CODES_BY_LOCALE[locale]
  end
end
