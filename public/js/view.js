(function() {
    "use strict";

    var lastKeys = "";
    function fetchRedlines() {
        var baseUrl = $('#baseUrl').val();
        var artworkUrl = $('#artworkUrl').val();
        $.get(baseUrl + 'index').done(function(keys) {
            if (lastKeys === keys) {
                return;
            }
            lastKeys = keys;

            var items = [];
            var requests = $.map(keys.split('\n'), function(key) {
                return $.get(baseUrl + key).done(function(data) {
                    var json = JSON.parse(data);
                    var feedback = $('<div/>').text(json.feedback).addClass('feedback');
                    var artwork = $('<div/>').append($('<img/>').attr('src', artworkUrl))
                                             .append($('<img/>').attr('src', json.image).addClass('redline'))
                                             .addClass('drawing');
                    var item = $('<div/>').append(feedback)
                                          .append(artwork)
                                          .attr('id', key);
                    items.push(item);
                }).fail(function() {
                    console.log('Failed to fetch data for key ' + key);
                });
            });

            $.when.apply($, requests).done(function () {
                $('#items').empty();
                $.each(items, function(i, item) {
                    $('#items').append(item);
                });
                $('#submissions').text(items.length);
            });

        }).fail(function() {
            console.log('Failed to fetch index file');
        });
    }

    $(function() {
        fetchRedlines();
        setInterval(fetchRedlines, 5000);
    });
})();
