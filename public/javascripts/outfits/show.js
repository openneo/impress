var main_wardrobe = new Wardrobe(), View = Wardrobe.getStandardView({
  Preview: {
    swf_url: '/swfs/preview.swf?v=0.12',
    wrapper: $('#preview-wrapper'),
    placeholder: $('#preview-swf')
  }
});
main_wardrobe.registerViews(View);
main_wardrobe.initialize();
main_wardrobe.outfit.loadData(INITIAL_OUTFIT_DATA);
