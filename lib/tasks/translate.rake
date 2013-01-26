require 'rocketamf/remote_gateway'

namespace :translate do
  def with_given_locale
    I18n.with_locale(ENV['LOCALE']) do
      language_code = I18n.neopets_language_code_for(I18n.locale)
      unless language_code
        raise "Locale #{I18n.locale.inspect} has no neopets language code"
      end
      
      yield(language_code)
    end
  end
  
  desc "Download the Neopets zone data for the given locale"
  task :zones => :environment do
    with_given_locale do |neopets_language_code|
      gateway = RocketAMF::RemoteGateway.new(Pet::GATEWAY_URL)
      action = gateway.service('CustomPetService').action('getApplicationData')
      envelope = action.request([]).post(
        :headers => {
          'Cookie' => "lang=#{neopets_language_code}"
        }
      )
      application_data = envelope.messages[0].data.body
      
      zones_by_id = Zone.all.inject({}) { |h, z| h[z.id] = z ; h}
      application_data[:zones].each do |zone_data|
        zone = zones_by_id[zone_data[:id].to_i]
        zone.label = zone_data[:label]
        zone.plain_label = Zone.plainify_label(zone.label)
        zone.save!
      end
    end
  end
end
