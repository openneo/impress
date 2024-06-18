class Item
	module Dyeworks
		def dyeworks?
      dyeworks_base_item.present?
    end

    # Whether this is a Dyeworks item whose base item can currently be purchased
    # in the NC Mall, then dyed via Dyeworks. (Owls tracks this last part!)
    def dyeworks_buyable?
      dyeworks_base_buyable? && dyeworks_dyeable?
    end

    # Whether this is a Dyeworks item whose base item can currently be purchased
    # in the NC Mall. It may or may not currently be *dyeable* in the NC Mall,
    # because Dyeworks eligibility is often a limited-time event.
    def dyeworks_base_buyable?
      dyeworks_base_item.present? && dyeworks_base_item.currently_in_mall?
    end

    # Whether this is a Dyeworks item that can be dyed in the NC Mall ~right now,
    # either at any time or as a limited-time event. (Owls tracks this, not us!)
    def dyeworks_dyeable?
      dyeworks_permanent? || dyeworks_limited?
    end

    # Whether this is one of the few Dyeworks items that can be dyed in the NC
    # Mall at any time, rather than as part of a limited-time event. (Owls tracks
    # this, not us!)
    DYEWORKS_PERMANENT_PATTERN = /Permanent Dyeworks/i
    def dyeworks_permanent?
      return false if nc_trade_value.nil?
      nc_trade_value.value_text.match?(DYEWORKS_PERMANENT_PATTERN)
    end

    # Whether this is a Dyeworks item that can be dyed in the NC Mall ~right now,
    # but only as part of a limited-time event. (Owls tracks this, not us!)
    DYEWORKS_LIMITED_PATTERN = /Limited Dyeworks/i
    def dyeworks_limited?
      return false if nc_trade_value.nil?
      nc_trade_value.value_text.match?(DYEWORKS_LIMITED_PATTERN)
    end

    # Infer what base item this Dyeworks item probably relates to, based on
    # their names. We only use this when a new item is modeled to initialize
    # the `dyeworks_base_item` relationship in the database; after that, we
    # just use whatever the database says. (This allows manual overrides!)
    DYEWORKS_NAME_PATTERN = %r{
      ^(
        # Most Dyeworks items have a colon in the name.
        Dyeworks\s+(?<color>.+?:)\s*(?<base>.+)
        |
        # But sometimes they omit it. If so, assume the first word is the color!
        Dyeworks\s+(?<color>\S+)\s*(?<base>.+)
      )$
    }x
    def inferred_dyeworks_base_item
      name_match = name.match(DYEWORKS_NAME_PATTERN)
      return nil if name_match.nil?

      Item.find_by_name(name_match["base"])
    end
	end
end