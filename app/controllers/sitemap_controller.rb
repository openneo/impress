class SitemapController < ApplicationController
  layout nil

  def index
    respond_to do |format|
      format.xml { @items = Item.sitemap }
    end
  end
end

