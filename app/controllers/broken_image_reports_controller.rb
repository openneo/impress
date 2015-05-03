class BrokenImageReportsController < ApplicationController
  def new
    @swf_assets = SwfAsset.from_wardrobe_link_params(params[:asset_ids]).where(:has_image => true)
  end

  def create
    swf_asset = SwfAsset.where(:type => params[:swf_asset_type]).
      find_by_remote_id(params[:swf_asset_remote_id])

    if swf_asset.image_manual?
      flash[:warning] = t('broken_image_reports.create.manual')
    else
      # If the asset is already reported as broken, no need to shout about it.
      # Just don't enqueue it, thank the user, and move on.
      swf_asset.report_broken
      flash[:success] = t('broken_image_reports.create.success')
    end

    redirect_to :back
  end
end

