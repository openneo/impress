class Roulette
  attr_accessor :pet_type, :pet_state, :item_ids
  
  def initialize
    # Choose a random pet type, and get a random state
    @pet_type = PetType.offset(rand(PetType.count)).first # random pet type
    states = @pet_type.pet_states
    @pet_state = states.offset(rand(states.count)).first
    fitting_swf_assets = SwfAsset.object_assets.fitting_body_id(@pet_type.body_id)
    
    # Keep going until we have all zones occupied. Find a random SWF asset for
    # a given unoccupied zone, then look up its item to see if it affects or
    # restricts zones we've already used. If so, try again. If not, add it to
    # the list.
    unoccupied_zone_ids = Zone.all.map(&:id)
    swf_asset_count_by_zone_id = fitting_swf_assets.count(:group => :zone_id)
    swf_asset_count_by_zone_id.default = 0
    @item_ids = []
    while !unoccupied_zone_ids.empty?
      zone_id = unoccupied_zone_ids.slice!(rand(unoccupied_zone_ids.count))
      swf_asset_count = swf_asset_count_by_zone_id[zone_id]
      if swf_asset_count > 0
        used_swf_asset_ids = []
        first_asset = true
        found_item = false
        while !found_item && used_swf_asset_ids.size < swf_asset_count
          base = fitting_swf_assets
          unless first_asset
            first_asset = false
            base = base.where(fitting_swf_assets.arel_table[:id].not_in(used_swf_asset_ids))
          end
          swf_asset = base.
            where(:zone_id => zone_id).
            offset(rand(swf_asset_count)).
            includes(:object_asset_relationships => :item).
            first
          used_swf_asset_ids.push(swf_asset.id)
          swf_asset.object_asset_relationships.each do |rel|
            item = rel.item
            if item.species_support_ids.empty? || item.species_support_ids.include?(@pet_type.species_id)
              pass = true
              item.affected_zones.each do |zone|
                checked_zone_id = zone.id
                next if checked_zone_id == zone_id
                if i = unoccupied_zone_ids.find_index(zone_id)
                  unoccupied_zone_ids.delete zone_id
                else
                  # This zone is already occupied, so this item is no good.
                  pass = false
                  break
                end
              end
              if pass
                found_item = true
                @item_ids << item.id
                break
              end
            end
          end
          break if found_item
        end
      end
    end
  end
  
  def to_query
    {
      :color => @pet_type.color_id,
      :species => @pet_type.species_id,
      :state => @pet_state.id,
      :objects => @item_ids
    }.to_query
  end
end
