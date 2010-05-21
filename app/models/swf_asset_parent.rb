module SwfAssetParent
  def swf_assets
    rels = ParentSwfAssetRelationship.arel_table
    type = self.class::SwfAssetType
    ids = ParentSwfAssetRelationship.
      where(rels[:parent_id].eq(id).and(rels[:swf_asset_type].eq(type))).
      select(rels[:swf_asset_id]).
      all.map(&:swf_asset_id)
    assets = SwfAsset.arel_table
    SwfAsset.where(assets[:id].in(ids).and(assets[:type].eq(type)))
  end
end
