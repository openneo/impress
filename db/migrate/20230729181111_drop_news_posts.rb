class DropNewsPosts < ActiveRecord::Migration
  def change
    drop_table :news_posts do |t|
      t.text :body
      t.string :html_class, default: 'success'

      t.timestamps
    end
  end
end
