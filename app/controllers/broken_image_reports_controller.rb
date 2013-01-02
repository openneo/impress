class BrokenImageReportsController < ApplicationController
  def new
    ids = params[:asset_ids]
    assets = SwfAsset.arel_table
    @swf_assets = SwfAsset.where(:has_image => true).where((
        assets[:remote_id].in(ids[:biology]).and(assets[:type].eq('biology'))
      ).or(
        assets[:remote_id].in(ids[:object]).and(assets[:type].eq('object'))
      ))
  end

  def create
    swf_asset = SwfAsset.where(:type => params[:swf_asset_type]).
      find_by_remote_id(params[:swf_asset_remote_id])

    if swf_asset.report_broken
      flash[:success] = t('broken_image_reports.create.success')
    else
      flash[:alert] = t('broken_image_reports.create.already_reported')
    end

    redirect_to :back
  end
end

