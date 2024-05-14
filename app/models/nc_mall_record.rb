class NCMallRecord < ApplicationRecord
  belongs_to :item

  def current_price
    discount_price || price
  end
end
