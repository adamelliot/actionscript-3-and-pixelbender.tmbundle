// Setup a namespace if we don't have one for our classes.
if (!window.Warptube) Warptube = {};

Warptube.Debug = function() {

  return {
    loadSWF: function(file, width, height, color) {
      $("#player_container").contents('<div id="player"></div>');
      $("body").css({backgroundColor: color, width: width + "px"});

      // I assume that the version of flash required is 10 cause that's what
      // the dev tools support. That doesn't mean the file was compiled for 10.
      swfobject.embedSWF(file, 'player', width, height, '10', null, null,
        {bgcolor: color});

      $("#player").css({border: "thin solid rgba(255,0,0,0.3)"});
    },

    trace: function (str) {
      $("#trace").append(str + "<br />");
      $("#trace").get(0).scrollByLines(1);
    }
  }
}();

alert = Warptube.Debug.trace;