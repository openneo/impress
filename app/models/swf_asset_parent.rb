module SwfAssetParent
  def swf_assets
    rels = Table(ParentSwfAssetRelationship.table_name)
    type = self.class::SwfAssetType
    ids = ParentSwfAssetRelationship.
      where(rels[:parent_id].eq(id).and(rels[:swf_asset_type].eq(type))).
      select(rels[:swf_asset_id]).
      all.map(&:swf_asset_id)
    assets = Table(SwfAsset.table_name)
    SwfAsset.where(assets[:id].in(ids)).all
  end
end
