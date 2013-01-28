require 'rocketamf/remote_gateway'

namespace :translate do
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
      
      zones_by_id = Zone.all.inject({}) { |h, z| h[z.id] = z ; h }
      application_data[:zones].each do |zone_data|
        zone = zones_by_id[zone_data[:id].to_i]
        zone.label = zone_data[:label]
        zone.plain_label = Zone.plainify_label(zone.label)
        zone.save!
      end
    end
  end
  
  desc "Download the Rainbow Pool data for the given locale"
  task :pet_attributes => :environment do
    with_given_locale do |neopets_language_code|
      pool_url = "http://www.neopets.com/pool/all_pb.phtml"
      pool_options = {
        :cookies => {:neologin => URI.encode(ENV['NEOLOGIN'])},
        :params => {:lang => neopets_language_code}
      }
      pool_response = RestClient.get(pool_url, pool_options)
      pool_doc = Nokogiri::HTML(pool_response)
      
      [Species, Color].each do |klass|
        klass_name = klass.name.underscore
        records_by_id = klass.all.inject({}) { |h, r| h[r.id] = r; h }
        pool_doc.css("select[name=f_#{klass_name}_id] option").each do |option|
          record = records_by_id[option['value'].to_i]
          record.name = option.text.downcase
          record.save!
        end
      end
    end
  end
  
  def with_given_locale
    I18n.with_locale(ENV['LOCALE']) do
      language_code = I18n.compatible_neopets_language_code_for(I18n.locale)
      unless language_code
        raise "Locale #{I18n.locale.inspect} has no neopets language code"
      end
      
      yield(language_code)
    end
  end
end
