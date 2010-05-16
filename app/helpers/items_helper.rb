module ItemsHelper
  StandardSpeciesImageFormat = 'http://pets.neopets.com/cp/%s/1/1.png'
  
  def standard_species_images
    colors = Species::StandardColors
    raw(Species.all.inject('') do |html, species|
      color = colors[rand(colors.size)]
      src = sprintf(StandardSpeciesImageFormat, species.hash_for_color(color))
      html + image_tag(src, 'data-color' => color, 'data-species' => species.name)
    end)
  end
end
