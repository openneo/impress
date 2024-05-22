class AddPbItemThumbnailUrlToColors < ActiveRecord::Migration[7.1]
  def change
    add_column :colors, :pb_item_thumbnail_url, :string
  end
end
