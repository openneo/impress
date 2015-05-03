class SwfAssetsController < ApplicationController
  def index
    if params[:item_id]
      item = Item.find(params[:item_id])
      @swf_assets = item.swf_assets.includes_depth
      if params[:body_id]
        @swf_assets = @swf_assets.fitting_body_id(params[:body_id])
      else
        if item.special_color
          @swf_assets = @swf_assets.fitting_color(item.special_color)
        else
          @swf_assets = @swf_assets.fitting_standard_body_ids
        end
        json = @swf_assets.all.group_by(&:body_id)
      end
    elsif params[:pet_type_id] && params[:item_ids]
      pet_type = PetType.find(params[:pet_type_id], :select => [:body_id, :species_id])
      
      @swf_assets = SwfAsset.object_assets.includes_depth.
        fitting_body_id(pet_type.body_id).
        for_item_ids(params[:item_ids]).
        with_parent_ids
      json = @swf_assets.map { |a| a.as_json(:parent_id => a.parent_id.to_i, :for => 'wardrobe') }
    elsif params[:pet_state_id]
      @swf_assets = PetState.find(params[:pet_state_id]).swf_assets.
        includes_depth.all
      pet_state_id = params[:pet_state_id].to_i
      json = @swf_assets.map { |a| a.as_json(:parent_id => pet_state_id, :for => 'wardrobe') }
    elsif params[:pet_type_id]
      @swf_assets = PetType.find(params[:pet_type_id]).pet_states.emotion_order
        .first.swf_assets.includes_depth
    elsif params[:ids]
      @swf_assets = []
      if params[:ids][:biology]
        @swf_assets += SwfAsset.includes_depth.biology_assets.where(:remote_id => params[:ids][:biology]).all
      end
      if params[:ids][:object]
        @swf_assets += SwfAsset.includes_depth.object_assets.where(:remote_id => params[:ids][:object]).all
      end
    elsif params[:body_id] && params[:item_ids]
      # DEPRECATED in favor of pet_type_id and item_ids
      swf_assets = SwfAsset.arel_table
      @swf_assets = SwfAsset.includes_depth.object_assets.
        select('swf_assets.*, parents_swf_assets.parent_id').
        fitting_body_id(params[:body_id]).
        for_item_ids(params[:item_ids])
      json = @swf_assets.map { |a| a.as_json(:parent_id => a.parent_id.to_i, :for => 'wardrobe') }
    end
    if @swf_assets
      @swf_assets = @swf_assets.all unless @swf_assets.is_a? Array
      @swf_assets.each(&:request_image_conversion!)
      json = @swf_assets unless json
    else
      json = nil
    end
    render :json => json
  end

  def show
    @swf_asset = SwfAsset.find params[:id]
    render :json => @swf_asset
  end

  def links
    @swf_assets = SwfAsset.from_wardrobe_link_params(params[:asset_ids])
  end
end

