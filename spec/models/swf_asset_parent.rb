module SwfAssetParent
  def swf_assets
    rels = Table(ParentSwfAssetRelationship.table_name)
    swf_asset_ids = ParentSwfAssetRelationship.where(
      rels[:parent_id].eq(id).and(rels[:swf_asset_type].eq(swf_asset_type))
    ).map(&:swf_asset_id)
    swf_assets = Table(SwfAsset.table_name)
    SwfAsset.where(swf_assets[:id].in(swf_asset_ids))
  end
end
