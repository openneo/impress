# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end

ActiveSupport::Inflector.inflections(:en) do |inflect|
  # Teach Zeitwerk that `RocketAMF` is what to expect in `lib/rocketamf`.
  inflect.acronym "RocketAMF"

  # Teach Zeitwerk that `NeoPass` is what to expect in `app/services/neopass.rb`.
  inflect.acronym "NeoPass"

  # Teach Zeitwerk that "NCMall" is what to expect in `app/services/nc_mall.rb`.
  # (We do this by teaching it the word "NC".)
  inflect.acronym "NC"
end
