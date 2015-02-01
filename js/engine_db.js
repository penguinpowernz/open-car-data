var EngineDB = (function() {
  var db     = null;
  var ls_key = "OCD:engines";
  var ready  = function() {};

  var init = function() {
    db = JSON.parse(localStorage.getItem(ls_key));

    if ( db == null ) {
      load_db(ready);
    } else {
      ready();
    }

  };

  var get = function(code) {
    return db[code];
  };

  var load_db = function(callback) {
    $.getJSON("/data/engines.json", function(json) {
      db = json;
      localStorage.setItem(ls_key, JSON.stringify(json));
      callback();
    });
  };

  var codes = function() {
    return Object.keys(db);
  };

  var codes_with_manufacturer = function() {
    codes = [];
    
    for (code in db) {
      codes.push(code+" ("+db[code]["manufacturer"].join("/")+")");
    }

    return codes;
  };

  var ready = function(callback) {
    ready = callback;
  };

  return {
    init: init,
    codes: codes,
    get: get,
    ready: ready,
    codes_with_manufacturer: codes_with_manufacturer
  };
}());
