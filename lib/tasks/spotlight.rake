require 'nokogiri'

namespace :spotlight do

  desc "Update spotlight pets by HTML download of contest results"
  task :update do |t, args|
    input_path = args[:file]
    unless input_path
      raise ArgumentError, "provide FILE=/path/to/contest/results.html"
    end
    
    input_doc = File.open(input_path, 'r') { |file| Nokogiri::HTML(file) }
    
    output_path = Rails.root.join('public', 'spotlight_pets.txt')
    File.open(output_path, 'w') do |output_file|
      links = input_doc.css('a[href^="/petlookup.phtml"]')
      
      links.each do |link|
        output_file.puts(link.text)
      end
      
      puts "Wrote #{links.size} names to #{output_path}"
    end
  end

end
