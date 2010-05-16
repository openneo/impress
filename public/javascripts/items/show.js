var PREVIEW_SWF_ID = 'item-preview-swf';

swfobject.embedSWF(
  'http://impress.openneo.net/assets/swf/preview.swf', // URL
  PREVIEW_SWF_ID, // ID
  400, // width
  400, // height
  9, // required version
  'http://impress.openneo.net/assets/js/swfobject/expressInstall.swf', // express install URL
  {'swf_assets_path': '/assets'}, // flashvars
  {'wmode': 'transparent'} // params
)
