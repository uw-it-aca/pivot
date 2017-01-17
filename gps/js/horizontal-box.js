(function() {

// Inspired by http://informationandvisualization.de/blog/box-plot
d3.box = function() {
  var width = 1,
      height = 1,
      duration = 0,
      domain = null,
      value = Number,
      whiskers = boxWhiskers,
      quartiles = boxQuartiles,
	  showLabels = true, // whether or not to show text labels
      customGPA = null;

  // For each small multiple…
  function box(g) {
    g.each(function(data, i) {
      //d = d.map(value).sort(d3.ascending);
	  //var boxIndex = data[0];
	  //var boxIndex = 1;
      // console.log(boxIndex); 
	  //console.log(d); 
	  
      var g = d3.select(this);

      // Compute quartiles. Must return exactly 3 elements.
      var quartileData = [data["q1"], data["median"], data["q3"]];

      // Compute whiskers. Must return exactly 2 elements, or null.

      var whiskerData = [data["iqr_min"], data["iqr_max"]];
      // Compute outliers. If no whiskers are specified, all data are "outliers".
      // We compute the outliers as indices, so that we can join across transitions!

     // Compute the new y-scale.
      var y1 = d3.scale.linear()
          .domain([1.5, 4])
          .range([0, width]);

      // Retrieve the old y-scale, if this is an update.
      var y0 = this.__chart__ || d3.scale.linear()
          .domain([0, Infinity])
          .range(y1.range());

      // Stash the new scale.
      this.__chart__ = y1;

      // Note: the box, median, and box tick elements are fixed in number,
      // so we only have to handle enter and update. In contrast, the outliers
      // and other elements are variable, so we need to exit them! Variable
      // elements also fade in and out.

      // Update center line: the horizontal line spanning the whiskers.
      var center = g.selectAll("line.center")
          .data(whiskerData ? [whiskerData] : []);

     //Horizontal line
        center.enter().insert("line", "rect")
            .attr("class","center")
            .attr("x1", function(d) { return y0(d[0]); })
            .attr("y1", height / 2)
            .attr("x2", function(d) { return y0(d[1]); })
            .attr("y2", height / 2)
            .style("opacity", 1e-6);
        
        center.transition()
          .duration(duration)
          .style("opacity", 1)
          .attr("x1", function(d) { return y1(d[0]); })
          .attr("x2", function(d) { return y1(d[1]); });

      center.exit().transition()
          .duration(duration)
          .style("opacity", 1e-6)
          .attr("x1", function(d) { return y1(d[0]); })
          .attr("x2", function(d) { return y1(d[1]); })
          .remove();

      // Update innerquartile box.
      var boxLQ = g.selectAll("rect.box")
          .data([quartileData]);

      boxLQ.enter().append("rect")
          .attr("class", "boxLQ")
          .attr("data",quartileData[0])
          .attr("x", function(d) { return y0(d[0]); })
          .attr("y", 0)
          .attr("width", function(d) { return y0(d[1]) - y0(d[0]); })
          .attr("height", height)
        .transition()
          .duration(duration)
          .attr("x", function(d) { return y1(d[0]); })
          .attr("width", function(d) { return y1(d[1]) - y1(d[0]); });

      boxLQ.transition()
          .duration(duration)
          .attr("x", function(d) { return y1(d[0]); })
          .attr("width", function(d) { return y1(d[1]) - y1(d[0]); });
      
        var boxHQ = g.selectAll("rect.box")
          .data([quartileData]);

      boxHQ.enter().append("rect")
          .attr("class", "boxHQ")
          .attr("data",quartileData[2])
          .attr("x", function(d) { return y0(d[1]); })
          .attr("y", 0)
          .attr("width", function(d) { return y0(d[2]) - y0(d[1]); })
          .attr("height", height)
        .transition()
          .duration(duration)
          .attr("x", function(d) { return y1(d[1]); })
          .attr("width", function(d) { return y1(d[2]) - y1(d[1]); });

      boxHQ.transition()
          .duration(duration)
          .attr("x", function(d) { return y1(d[1]); })
          .attr("width", function(d) { return y1(d[2]) - y1(d[1]); });

      // Update median line.
      var medianLine = g.selectAll("line.median")
          .data([quartileData[1]]);

      medianLine.enter().append("line")
          .attr("class", "median")
          .attr("data",quartileData[1])
          .attr("x1", y0)
          .attr("y1", 0)
          .attr("x2", y0)
          .attr("y2", height)
        .transition()
          .duration(duration)
          .attr("x1", y1)
          .attr("x2", y1);

      medianLine.transition()
          .duration(duration)
          .attr("x1", y1)
          .attr("x2", y1);

      // Update whiskers.
      var whisker = g.selectAll("line.whisker")
          .data(whiskerData || []);

      whisker.enter().insert("line", "circle, text")
          .attr("class", "whisker")
          .attr("x1", y0)
          .attr("y1", 0)
          .attr("x2", y0)
          .attr("y2", 0 + height)
          .style("opacity", 1e-6)
        .transition()
          .duration(duration)
          .attr("x1", y1)
          .attr("x2", y1)
          .style("opacity", 1);

      whisker.transition()
          .duration(duration)
          .attr("x1", y1)
          .attr("x2", y1)
          .style("opacity", 1);

      whisker.exit().transition()
          .duration(duration)
          .attr("x1", y1)
          .attr("x2", y1)
          .style("opacity", 1e-6)
          .remove();
        
        //Add in customGPA, including extra tick
        if (customGPA != null) {
            var gpa = g.selectAll("line.gpaPlaceholder").data([customGPA]);
            
            gpa.enter().insert("line")
                .attr("class","gpaPlaceholder")
                .attr("x1", y0)
                .attr("y1", -10)
                .attr("x2", y0)
                .attr("y2", height + 20)
                .style("opacity", 0)
                .transition()
                  .duration(duration)
                  .attr("x1", y1)
                  .attr("x2", y1)
                  .style("opacity", 0);
            gpa.transition()
              .duration(duration)
              .attr("x1", y1)
              .attr("x2", y1)
              .style("opacity", 0);

          gpa.exit().transition()
              .duration(duration)
              .attr("x1", y1)
              .attr("x2", y1)
              .style("opacity", 0)
              .remove();
        }

      // Update box ticks.
      var boxTick = g.selectAll("text.box")
          .data(quartileData);
	 if(showLabels == true) {
      boxTick.enter().append("text")
          .attr("class", "box")
          .attr("dy", function(d, i) { return i & 1 ? 6 : -6 })
          .attr("dx", ".3em")
          .attr("x", y0)
          .attr("y", function(d, i) { return i & 1 ?  + height : 0 })
          .attr("text-anchor", function(d, i) { return i & 1 ? "start" : "end"; })
        .transition()
          .duration(duration)
          .attr("x", y1);
	}
		 
      boxTick.transition()
          .duration(duration)
          .attr("x", y1);

      // Update whisker ticks. These are handled separately from the box
      // ticks because they may or may not exist, and we want don't want
      // to join box ticks pre-transition with whisker ticks post-.
      var whiskerTick = g.selectAll("text.whisker")
          .data(whiskerData || []);
	if(showLabels == true) {
      whiskerTick.enter().append("text")
          .attr("class", "whisker")
          .attr("dy", 6)
          .attr("dx", ".3em")
          .attr("x", y0)
          .attr("y", height)
          .style("opacity", 1e-6)
        .transition()
          .duration(duration)
          .attr("x", y1)
          .style("opacity", 1);
	}
      whiskerTick.transition()
          .duration(duration)
          .attr("x", y1)
          .style("opacity", 1);

      whiskerTick.exit().transition()
          .duration(duration)
          .attr("x", y1)
          .style("opacity", 1e-6)
          .remove();
    });
    d3.timer.flush();
  }

  box.width = function(x) {
    if (!arguments.length) return width;
    width = x;
    return box;
  };

  box.height = function(x) {
    if (!arguments.length) return height;
    height = x;
    return box;
  };
    
  box.duration = function(x) {
    if (!arguments.length) return duration;
    duration = x;
    return box;
  };

  box.domain = function(x) {
    if (!arguments.length) return domain;
    domain = x == null ? x : d3.functor(x);
    return box;
  };

  box.value = function(x) {
    if (!arguments.length) return value;
    value = x;
    return box;
  };

  box.whiskers = function(x) {
    if (!arguments.length) return whiskers;
    whiskers = x;
    return box;
  };
  
  box.showLabels = function(x) {
    if (!arguments.length) return showLabels;
    showLabels = x;
    return box;
  };
    
  box.quartiles = function(x) {
    if (!arguments.length) return quartiles;
    quartiles = x;
    return box;
  };
    
box.customGPA = function(x) {
    if (!arguments.length) return customGPA;
    customGPA = x;
    return box;
}

  return box;
};

function boxWhiskers(d) {
  return [0, d.length - 1];
}

function boxQuartiles(d) {
  return [
    d3.quantile(d, .25),
    d3.quantile(d, .5),
    d3.quantile(d, .75)
  ];
}

})();
