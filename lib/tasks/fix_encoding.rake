namespace :db do
  desc "Fix double-encoded UTF-8 strings in item names and descriptions"
  task fix_double_encoding: :environment do
    puts "=" * 80
    puts "Fix Double-Encoded Strings in Database"
    puts "=" * 80
    puts

    # Define the double-encoding patterns and their fixes
    # Each pattern maps: double-encoded string -> correct UTF-8 string
    # Using byte arrays to avoid encoding issues in the source file itself
    encoding_fixes = {
      # Common accented characters (Ă© => é, etc.)
      "\xC4\x82\xC2\xA9".force_encoding('UTF-8') => "\xC3\xA9".force_encoding('UTF-8'),  # é
      "\xC4\x82\xC2\xB1".force_encoding('UTF-8') => "\xC3\xB1".force_encoding('UTF-8'),  # ñ
      "\xC4\x82\xC2\xAD".force_encoding('UTF-8') => "\xC3\xAD".force_encoding('UTF-8'),  # í
      "\xC4\x82\xC2\xA1".force_encoding('UTF-8') => "\xC3\xA1".force_encoding('UTF-8'),  # á
      "\xC4\x82\xC2\xB3".force_encoding('UTF-8') => "\xC3\xB3".force_encoding('UTF-8'),  # ó
      "\xC4\x82\xC2\xBA".force_encoding('UTF-8') => "\xC3\xBA".force_encoding('UTF-8'),  # ú

      # Smart quotes and apostrophes
      "\xC3\xA2\xE2\x82\xAC\xE2\x84\xA2".force_encoding('UTF-8') => "\xE2\x80\x99".force_encoding('UTF-8'),  # '
      "\xC3\xA2\xE2\x82\xAC\xC5\x93".force_encoding('UTF-8') => "\xE2\x80\x9C".force_encoding('UTF-8'),  # "
      "\xC3\xA2\xE2\x82\xAC\xC2\x9D".force_encoding('UTF-8') => "\xE2\x80\x9D".force_encoding('UTF-8'),  # "
      "\xC3\xA2\xE2\x82\xAC\xCB\x9C".force_encoding('UTF-8') => "\xE2\x80\x98".force_encoding('UTF-8'),  # '

      # Other punctuation
      "\xC3\xA2\xE2\x82\xAC\xE2\x80\x9C".force_encoding('UTF-8') => "\xE2\x80\x93".force_encoding('UTF-8'),  # –
      "\xC3\xA2\xE2\x82\xAC\xE2\x80\x9D".force_encoding('UTF-8') => "\xE2\x80\x94".force_encoding('UTF-8'),  # —
      "\xC3\xA2\xE2\x82\xAC\xC2\xA6".force_encoding('UTF-8') => "\xE2\x80\xA6".force_encoding('UTF-8'),  # …

      # Non-breaking space
      "\xC3\x82\xC2\xA0".force_encoding('UTF-8') => "\xC2\xA0".force_encoding('UTF-8'),
    }

    puts "Will fix the following patterns:"
    encoding_fixes.each do |bad, good|
      puts "  #{bad.inspect} → #{good.inspect}"
    end
    puts

    # Find affected items by actually checking for the pattern in Ruby
    # (MySQL LIKE queries give false positives with multi-byte UTF-8)
    puts "Scanning items for double-encoding patterns..."

    items_by_pattern = {}
    total_affected = Set.new
    count_by_pattern = Hash.new { |h, k| h[k] = { name: 0, description: 0 } }

    Item.find_each do |item|
      encoding_fixes.each_key do |pattern|
        if item.name.include?(pattern)
          items_by_pattern[pattern] ||= { name: [], description: [] }
          items_by_pattern[pattern][:name] << item.id
          total_affected << item.id
          count_by_pattern[pattern][:name] += 1
        end

        if item.description.include?(pattern)
          items_by_pattern[pattern] ||= { name: [], description: [] }
          items_by_pattern[pattern][:description] << item.id
          total_affected << item.id
          count_by_pattern[pattern][:description] += 1
        end
      end
    end

    puts
    count_by_pattern.each do |pattern, counts|
      puts "#{pattern.inspect}: #{counts[:name]} names, #{counts[:description]} descriptions"
    end

    puts
    puts "Total affected items: #{total_affected.size}"
    puts

    if total_affected.empty?
      puts "No items need fixing!"
      next
    end

    # Show some examples
    puts "Example affected items:"
    Item.where(id: total_affected.to_a.first(5)).each do |item|
      puts "  #{item.id}: #{item.name}"
    end
    puts "  ... and #{total_affected.size - 5} more" if total_affected.size > 5
    puts

    # Ask for confirmation
    print "Fix these items by replacing double-encoded characters? (y/N): "
    response = STDIN.gets.chomp
    unless response.downcase == 'y'
      puts "Aborted."
      next
    end

    puts
    puts "Fixing items..."
    puts "-" * 80

    fixed_count = 0
    no_change_count = 0

    Item.where(id: total_affected.to_a).find_each do |item|
      original_name = item.name
      original_description = item.description

      # Apply all fixes to name and description
      new_name = original_name.dup
      new_description = original_description.dup

      encoding_fixes.each do |bad, good|
        new_name.gsub!(bad, good)
        new_description.gsub!(bad, good)
      end

      # Only save if something changed
      if new_name != original_name || new_description != original_description
        item.name = new_name
        item.description = new_description
        item.save!(validate: false) # Skip validations to avoid potential issues

        if new_name != original_name
          puts "#{item.id}: #{original_name.inspect} → #{new_name.inspect}"
        elsif new_description != original_description
          puts "#{item.id}: Updated description only"
        end

        fixed_count += 1
      else
        no_change_count += 1
      end
    end

    puts
    puts "-" * 80
    puts "Complete!"
    puts "  ✓ Fixed: #{fixed_count}"
    puts "  ⊘ No changes needed: #{no_change_count}"
    puts

    # Show a sample of fixed items
    puts "Sample of fixed items:"
    Item.where(id: total_affected.to_a.first(5)).each do |item|
      puts "  #{item.id}: #{item.name}"
    end
    puts
  end
end
