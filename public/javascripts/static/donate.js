(function () {
  var PLEDGIE_CAMPAIGN_ID = $('meta[name=pledgie-campaign-id]').attr('content');

  var pledgieURL = 'http://pledgie.com/campaigns/' + PLEDGIE_CAMPAIGN_ID + '.json?callback=?';
  $.getJSON(pledgieURL, function (data) {
    var donorsEl = $('#campaign-donors');
    var donorsList = donorsEl.children('ol');
    var campaign = data.campaign;
    var pledges = campaign.pledges;

    var pledge, pledgeEl;
    for(var i in pledges) {
      pledge = pledges[i];
      pledgeEl = $('<li/>');
      $('<strong/>', {text: pledge.display_name}).appendTo(pledgeEl);
      $('<span/>', {text: pledge.date}).appendTo(pledgeEl);
      pledgeEl.appendTo(donorsList);
    }

    $(document.body).addClass('campaign-loaded');
  });
})();

