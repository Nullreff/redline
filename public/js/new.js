(function() {
    "use strict";

    function getTop(element) {
        return element.getBoundingClientRect().top + document.documentElement.scrollTop;
    }

    function getLeft(element) {
        return element.getBoundingClientRect().left;
    }

    function resizeContainers() {
        $('#drawing').css('height', ($(window).height() - getTop($('#drawing')[0]) - 5) + 'px');
        $('#drawing').css('width',  ($(window).width() - getLeft($('#drawing')[0]) - 5) + 'px');
        $('#feedback').css('height', ($(window).height() - getTop($('#feedback')[0]) - 7) + 'px');
    }

    function moveTo(element, x, y) {
        element.css('left', x + 'px');
        element.css('top', y + 'px');
    }

    function getPoint(e) {
        return {
            x: e.pageX - getLeft($('#drawing')[0]),
            y: e.pageY - getTop($('#drawing')[0])
        };
    }

    $(function() {
        var drawing = false;
        var mode = 'draw';
        var oldMouse = {};
        var imgAt = {};
        var clickAt = {};

        var drawSlider = 10;
        var eraseSlider = 50;

        $('#size').val(drawSlider);

        var c = $('#drawing canvas')[0].getContext('2d');
        var compositonDefault = c.globalCompositeOperation;

        resizeContainers();
        $(window).on('resize', function() {
            resizeContainers();
        });

        $('#drawing').mousedown(function(e) {
            clickAt = getPoint(e);
            imgAt = {
                x: parseInt($('#drawing img').css('left')),
                y: parseInt($('#drawing img').css('top'))
            };

            switch (mode) {
                case 'draw':
                    c.globalCompositeOperation = compositonDefault;
                    c.strokeStyle = '#FF0000';
                    break;
                case 'erase':
                    c.globalCompositeOperation = 'destination-out';
                    c.strokeStyle = 'rgba(0,0,0,1)';
                    break;
            }

            c.lineJoin = 'round';
            c.lineWidth = parseInt(Math.pow(2, $('#size').val() / 14));

            drawing = true;
        });

        $(window).mouseup(function() {
            drawing = false;
        });

        $(window).mousemove(function(e) {
            var mouse = getPoint(e);
            if (drawing) {
                switch (mode) {
                    case 'draw':
                    case 'erase':
                        c.beginPath();
                        c.moveTo(oldMouse.x - imgAt.x, oldMouse.y - imgAt.y);
                        c.lineTo(mouse.x - imgAt.x, mouse.y - imgAt.y);
                        c.closePath();
                        c.stroke();
                        break;

                    case 'move':
                        var newX = imgAt.x + (mouse.x - clickAt.x);
                        var newY = imgAt.y + (mouse.y - clickAt.y);
                        if (newX != 0 && newY != 0) {
                            moveTo($('#drawing img'), newX, newY);
                            moveTo($('#drawing canvas'), newX, newY);
                        }
                        break;
                }
            }

            oldMouse = mouse;
        });

        $('#controls li button').click(function() {
            $('#controls li button').removeClass('selected');
            $(this).addClass('selected');
            switch (mode) {
                case 'draw': drawSlider = $('#size').val(); break;
                case 'erase': eraseSlider = $('#size').val(); break;
            }
            mode = $(this).attr('data-mode');
            switch (mode) {
                case 'draw': $('#size').val(drawSlider); $('#sizeControl').show(); break;
                case 'erase': $('#size').val(eraseSlider); $('#sizeControl').show(); break;
                default: $('#sizeControl').hide();
            }
        });

        $('#submit').click(function() {
            $('#submit').attr('disabled', true);
            var data = {
                feedback: $('#feedback').val(),
                image: $('#drawing canvas')[0].toDataURL("image/png")
            };
            console.log(JSON.stringify(data));
            $.post(document.URL, JSON.stringify(data)).done(function() {
                $('#done').show();
            }).fail(function(xhr, status, error) {
                $('#submit').attr('disabled', false);
                console.log(error);
                alert('Oops, looks like we ran into an issue. Try submitting again.');
            });
        });
    });

    // Run after images are done downloading
    $(window).load(function() {
        var artwork = $('#drawing img');
        var redline = $('#drawing canvas');

        redline.attr('width', artwork.width());
        redline.attr('height', artwork.height());
    });
})();
