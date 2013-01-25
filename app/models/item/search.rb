class Item
  module Search
    def self.error(key, *args)
      message = I18n.translate("items.search.errors.#{key}", *args)
      raise Item::Search::Error, message
    end
  end
end
