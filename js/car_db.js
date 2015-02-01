var CarDB = (function() {
  var db     = {};

  var get = function(slugs) {
    cars = [];

    slugs.forEach(function(slug) {
      if ( db[slug] == null ) {
        $.ajax({
          url: "/cars/"+slug+".json",
          async: false,
          success: function(json) {
            cars.push(json);
            db[slug] = json;
          },
          format: "json"
        });
      } else {
        cars.push(db[slug]);
      }      
    });

    return cars;
  };

  return {
    get: get
  };

}());