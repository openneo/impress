class CreateNewsPosts < ActiveRecord::Migration
  def change
    create_table :news_posts do |t|
      t.text :body
      t.string :html_class, default: 'success'

      t.timestamps
    end
  end
end
