module StaticHelper
  def large_donation?(amount)
    amount > 100_00
  end

  def outfit_image?(outfit)
    outfit.present? && outfit.image?
  end
end
