(function () {
  var PLEDGIE_CAMPAIGN_ID = $('meta[name=pledgie-campaign-id]').attr('content');

  var pledgieURL = 'http://pledgie.com/campaigns/' + PLEDGIE_CAMPAIGN_ID + '.json?callback=?';
  $.getJSON(pledgieURL, function (data) {
    var campaign = data.campaign;

    // Write the donors list if we need to
    var donorsEl = $('#campaign-donors');
    if(donorsEl.length) {
      var donorsList = donorsEl.children('ol');
      var pledges = campaign.pledges;

      var pledge, pledgeEl;
      for(var i in pledges) {
        pledge = pledges[i];
        pledgeEl = $('<li/>');
        $('<strong/>', {text: pledge.display_name}).appendTo(pledgeEl);
        $('<span/>', {text: pledge.date}).appendTo(pledgeEl);
        pledgeEl.appendTo(donorsList);
      }

      if(pledges.length > 0) {
        donorsEl.addClass('has-donors');
      }
    }

    // Set campaign progress data
    $('span.campaign-raised').text(campaign.amount_raised);
    $('span.campaign-goal').text(campaign.goal);

    var campaign_percent = campaign.amount_raised / campaign.goal * 100;
    $('div.campaign-progress').css('width', campaign_percent + '%');

    $(document.body).addClass('campaign-loaded');
  });
})();

