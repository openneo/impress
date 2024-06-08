class AddDyeworksBaseItemIdToItems < ActiveRecord::Migration[7.1]
  def change
    add_reference :items, :dyeworks_base_item, type: :integer,
      foreign_key: {to_table: :items}

    # Find Dyeworks items, and fill in their base item field. (The Item model
    # is configured to try to infer this when saving Dyeworks-seeming items
    # with no matching base item yet.)
    #
    # Some item names that exist right now are known to not fit the pattern, so
    # we try to set them manually if present in this copy of the database.
    reversible do |direction|
      direction.up do
        dyeworks_items = Item.where("name LIKE ?", "Dyeworks %").to_a

        puts "Found #{dyeworks_items.size} Dyeworks items, " +
             "inferring base items…"
        dyeworks_items.each(&:save!)

        num_successes = dyeworks_items.select(&:dyeworks?).size
        puts "Inferred Dyeworks base item for #{num_successes} items"

        set_manually "Baby Valentine Jumper and Shirt",
                     "Dyeworks Baby Blue: Baby Valentine Jumper",
                     "Dyeworks Baby Pink: Baby Valentine Jumper",
                     "Dyeworks Purple: Baby Valentine Jumper"

        set_manually "Field of Flowers Foreground",
                     "Dyeworks Black: Field of Flowers",
                     "Dyeworks Blue: Field of Flowers",
                     "Dyeworks Yellow: Field of Flowers"

        set_manually "2010 Games Master Challenge NC Challenge Lulu Shirt",
                     "Dyeworks Black: Games Master Challenge 2010 Lulu Shirt",
                     "Dyeworks Orange: Games Master Challenge 2010 Lulu Shirt",
                     "Dyeworks Purple: Games Master Challenge 2010 Lulu Shirt"

        set_manually "Stars and Glitter Face Paint",
                     "Dyeworks Blue: Stars and Glitter Facepaint",
                     "Dyeworks Green: Stars and Glitter Facepaint",
                     "Dyeworks Purple: Stars and Glitter Facepaint"

        set_manually "Hanging Winter Candle Garland",
                     "Dyeworks Brown: Hanging Winter Candles Garland",
                     "Dyeworks Purple: Hanging Winter Candles Garland",
                     "Dyeworks Silver: Hanging Winter Candles Garland"

        set_manually "Lovely Berry Blush Makeup",
                     "Dyeworks Magenta: Lovely Berry Blush",
                     "Dyeworks Peach: Lovely Berry Blush",
                     "Dyeworks Soft Pink: Lovely Berry Blush"

        set_manually "Winter Lights Effect",
                     "Dyeworks Orange & Pink: Winter Lights Effects",
                     "Dyeworks Red & Green: Winter Lights Effects",
                     "Dyeworks Yellow & Magenta: Winter Lights Effects"

        danglers = Item.where("name LIKE ?", "Dyeworks %").
          where(dyeworks_base_item_id: nil).to_a
        puts "There are now #{danglers.size} Dyeworks-seeming items in the " +
             "database without a matching base item."
        danglers.each do |dangler|
          puts "- #{dangler.name}"
        end
      end
    end
  end

  private

  def set_manually(base_item_name, *dyeworks_item_names)
    base_item = Item.find_by_name(base_item_name)
    if base_item.nil?
      puts "Skipping all manual Dyeworks for base item #{base_item}: not found"
      return
    end

    dyeworks_item_names.each do |dyeworks_item_name|
      dyeworks_item = Item.find_by_name(dyeworks_item_name)
      if dyeworks_item.nil?
        puts "Skipping manual Dyeworks for #{base_item_name} -> " +
          "#{dyeworks_item_name}: not found"
        next
      end

      dyeworks_item.update!(dyeworks_base_item: base_item)
      puts "Manually assigned Dyeworks #{base_item_name} -> " +
        "#{dyeworks_item_name}"
    end
  end
end
