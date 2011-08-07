class BrokenImageReportsController < ApplicationController
  def new
    ids = params[:asset_ids]
    assets = SwfAsset.arel_table
    @swf_assets = SwfAsset.where(:has_image => true).where((
        assets[:id].in(ids[:biology]).and(assets[:type].eq('biology'))
      ).or(
        assets[:id].in(ids[:object]).and(assets[:type].eq('object'))
      ))
  end

  def create
    swf_asset = SwfAsset.find params[:swf_asset_id]

    if swf_asset.report_broken
      flash[:success] = "Thanks! This image will be reconverted soon. If it " +
        "looks the same after conversion, please consider sending a bug report."
    else
      flash[:alert] = "This image is already in line for reconversion. We'll " +
        "get to it soon, don't worry."
    end

    redirect_to :back
  end
end

