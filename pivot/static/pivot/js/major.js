//Functions specific to the major tab

/**** SETUP ****/
//If majors were already loaded (this session), automatically load them again
function checkStoredData() {
    //Check for stored major selections and gpa
    if (sessionStorage.getItem("majors")) {
        var majors = JSON.parse(sessionStorage.getItem("majors"));
        //GPA previously entered by user in compare gpa module
        var gpa = sessionStorage.getItem("gpa");
        // Compile the Handlebars template
        var source = $("#update-events").html();
        var template = Handlebars.compile(source);

        //Add selected majors to hidden area
        for (var m in majors)
            $(".selected").append(template({chosen: majors[m]}));
        //Populate data table
        if (majors != null)
            createMajorCard(majors, gpa = gpa == "null" ? null:gpa);
    } else $(".sample-data").css("display","block");
}

/**** DISPLAY DATA FOR SELECTED MAJOR(S) ****/

//Main function that draws/redraws the data table whenever a major is been selected
function createMajorCard(majors, gpa = null) {
    storeSelections(majors, gpa); //Store user's selections
    $(".sample-data").css("display","none"); //Hide the placeholder how-to image

    $("#clear_majors").css("display","inline"); //Changes css of "clear selections" button - not sure why

    //Hide any warning messages related to search
    $(".no-results-warning").css("display","none");
    $(".no-results-warning").removeClass("alert alert-info");

    //Clear any existing data
    $("#boxplots").html("");
    $(".yourgpa-box").remove();

    $(".results-section").css("display","inline"); //Changes css of results section - not sure why
    gpa = gpa == "" ? null:gpa;

    // Compile template with Handlebars
    var source = $("#create-major-card").html();
    var template = Handlebars.compile(source);

    //For each selected major...
    for (var l in majors) {

        //draw the major's data "card" in the table
        var id = majors[l].replace(" ","_");

        // Add the card
        $("#boxplots").append(template({
            id: id,
            college: _completeMajorMap[majors[l]]["college"],
            campus: _completeMajorMap[majors[l]]["campus"],
            major_status_url: displayMajorStatusURL(majors[l]),
            major_status_icon: displayMajorStatusIcon(majors[l])
        }));

        $("#" + id).data("code", majors[l]);
        var major = filterByMajors([majors[l]]);
        var med = major[0]["median"];

        //Add the initial content for the major
        createBoxForMajor(l, med, id);

        //Add the boxplot
        createBoxplot(l, gpa, id, med, major);
        //D3 - vars to pass = gpa, id, med, major

    }
    overlayGPA(gpa);
    showCompareModule(gpa = (gpa == null) ? "":gpa);
    $("#loadingModal").modal('hide');
}

//Creates the table cells for a major
function createBoxForMajor(i, median, majorId) {
    var display_median = parseFloat(median).toFixed(2); //formats the median major GPA for text display
    // Compile the Handlebars template
    var source = $("#create-box-for-major").html();
    var template = Handlebars.compile(source);
    //Create the data boxes, only show titles for first box
    var yes_or_no = i>=1 ? 0 : 1;
    $("#" + majorId).append(template({
        i: yes_or_no,
        display_median: display_median,
        major_id:majorId
    }));

    //Create the inline help popovers, only needed for major in first row
    if (i == 0) {
        // Compile the popover template if condition to display satisfies.
        var source = $("#median-help-popover").html();
        var template = Handlebars.compile(source);

        $("#medianHelp").popover({
            placement: "top",
            html: true,
            container: "body",
            content: template({})
        });
        $("#distributionHelp").popover({
            // Add some action here
        });
    }
}

//Draw boxplot using D3
function createBoxplot(i, gpa, majorId, median, majorData) {
    var height = 125;
    var width = $(".data-display").width();
    //create the boxplot
    var chart = d3.box().whiskers(iqr(1.5)).width(width).domain([1.5, 4.0]).showLabels(false).customGPA(gpa);
    var svg = d3.select("#" + majorId + " .data-display").append("svg").attr("width", width).attr("height", height).attr("class", "boxChart").append("g");

    //create the axes
    var y = d3.scale.ordinal().domain([median]).rangeRoundBands([0, height], 0.7, 0.3);
    var yAxis = d3.svg.axis().scale(y).orient("left");
    var x = d3.scale.linear().domain([1.5, 4.0]).range([0, width]);
    var xAxis = d3.svg.axis().scale(x).orient("top").ticks(6);

    //draw the boxplot
    svg.selectAll(".box").data(majorData).enter().append("a").attr("class","boxPopover").attr("tabindex",i).attr("role","button").attr("data-toggle","popover").attr("data-trigger","focus").append("g").attr("class","boxP").attr("transform", function(d) {return "translate(0," + y(median) + ")";}).call(chart.height(y.rangeBand() - 10));

    //draw the axes
    svg.append("g").attr("class", "x axis").attr("transform", "translate(0," + height + ")").call(xAxis).selectAll("text")
.style("text-anchor", "end");
    $("#" + majorId + " .card-heading, #"+majorId+" .median-box").height($("#" + majorId + " .data-display").height());

    //hide numbers for .5 ticks
    $(".tick text").each(function () {
        if ($(this).text().indexOf(".5") > 0) {
            $(this).hide();
        }
    });
    addPopover(majorId);
}

//Draw line representing user-entered GPA
function overlayGPA(gpa) {
    if ($(".gpaPlaceholder:first").length > 0) {
        $(".data-display").append('<div class="myGPA"></div>');
        var padding = Number($(".data-display:first").css("padding-left").replace("px",""));
        var left = padding + Number($(".gpaPlaceholder:first").attr("x1"));
        $(".myGPA").css({"left": left + "px"});
        $(".data-display").each(function (index, value) {
            $("#" + $(this).parent().attr("id") + " .myGPA").css("height",$(this).height() + "px");

        });
        $(".data-display:first").append('<div class="gpaLabel">Your GPA<br/>' + gpa + '</div>');
        $(".gpaLabel").css("left",(left - $(".gpaLabel").width()/2) + "px");
        $(".data-display:first .gpaLabel").css({"top":"0px","background-color":"#fff"});

    }
}

//Stores selected majors/gpa to pass between pages
function storeSelections(majors, gpa) {
    sessionStorage.setItem("majors", JSON.stringify(majors));
    sessionStorage.setItem("gpa", gpa);
}


//Initializes the popover for a boxplot
function addPopover(id) {
    // Compile the Handlebars template
    var source = $("#add-popover").html();
    var template = Handlebars.compile(source);

    $("#" + id + " .boxPopover").attr("data-content", template({
        lower_quartile: round(Number($("#" + id + " .boxLQ").attr("data")),2),
        median: round(Number($("#" + id + " .median").attr("data")),2),
        upper_quartile: round(Number($("#" + id + " .boxHQ").attr("data")),2)
    }));

    $("#" + id + " .boxPopover").popover({
        trigger: "hover click",
        placement: "top",
        html: true,
        container: "#" + id
    });
}


//Gets the data associated with the selected majors
function filterByMajors(list) {
    majors = [];

    for (index in list) {
        var major = list[index];
        majors.push(_majorLookup[major]);
    }
    return majors;
}

//resize d3 elements when window size changes
function resizeCharts() {
    var list = [];
    $(".chosen_major").each(function() {
        list.push($(this).text());
    });
    if (list.length > 0)
        createMajorCard(list,$("input#compare").val());
}

// Returns a function to compute the interquartile range.
function iqr(k) {
  return function(d, i) {
    console.trace("in the iqr function");
    var q1 = d.quartiles[0],
        q3 = d.quartiles[2],
        iqr = (q3 - q1) * k,
        i = -1,
        j = d.length;
    while (d[++i] < q1 - iqr);
    while (d[--j] > q3 + iqr);
      console.log(d.quartiles[1]);
    return [i, j];
  };
}

/***SEARCH***/

//Displays majors matching search term
function displayResults() {
    // Compile the Handlebars template for displaying results
    var source = $("#major-display-results").html();
    var template = Handlebars.compile(source);

    $("#suggestions").css("display","block");
    var count = 0;
    var search_val = $("#search").val().toLowerCase().replace('(','').replace(')','');
    for(var maj in _completeMajorMap) {
        var index = _completeMajorMap[maj]["major_full_nm"].toLowerCase().indexOf(search_val);
        //check matches for search term
        if (search_val.length > 0 && index > -1 && (index == 0 || _completeMajorMap[maj]["major_full_nm"].toLowerCase().charAt(index - 1) == " " || _completeMajorMap[maj]["major_full_nm"].toLowerCase().charAt(index - 1) == "(")) {
            //Find substring matching search term to make bold - should only highlight matches at beginning of word
            var substring = _completeMajorMap[maj]["major_full_nm"].substr(index, search_val.length);
            var appendTo = "";
            if (_completeMajorMap[maj]["college"] == $("#dropdownMenu:first-child").val())
                appendTo = "#selectedCollege";
            else if (_completeMajorMap[maj]["campus"] == _currentCampus)
                appendTo = "#currentCampus";
            else appendTo ="#" + _completeMajorMap[maj]["campus"].toLowerCase() + "Campus";
            var checked = "";
            $(".chosen_major").each(function() {
               if ($(this).text() == maj) {
                   checked = "checked";
               }
            });
            //Bolds search terms that appear at beginning of word other than first
            ///^(A|B|AB)$/
            $(appendTo).append(template({
                status: checked,
                data: _completeMajorMap[maj]["major_full_nm"].replace(new RegExp("\\b" + search_val, "ig"), "<b>" + substring + "</b>")
            }));
            $(appendTo + " li:last").data("code", maj);
            count++;
        }
        //else if nothing has been entered but a college is selected, load all majors in college
        else if (search_val.length == 0 && _completeMajorMap[maj]["college"] == $("#dropdownMenu:first-child").val()) {
            var appendTo = "#selectedCollege";
            var checked = "";
            $(".chosen_major").each(function() {
               if ($(this).text() == maj) {
                   checked = "checked";
               }
            });
            $(appendTo).append(template({
                status: checked,
                data: _completeMajorMap[maj]["major_full_nm"]
            }));
            $(appendTo + " li:last").data("code", maj);
            count++;
        }
    }
    if (count == 0 && search_val.length > 0) {
        if (all_data_loaded) {
           noResults();
           return;
        }
        update_results_on_load = true;
    }
}

//Shows any currently selected majors
function showCurrentSelections() {
    // Compile the Handlebars major-display-results template (shared template)
    var source = $("#major-display-results").html();
    var template = Handlebars.compile(source);

    $("#suggestions").css("display","block");
    $(".chosen_major").each(function() {
        var appendTo = "";
        if (_completeMajorMap[$(this).text()]["college"] == $("#dropdownMenu:first-child").val()) {
            appendTo = "#selectedCollege";
        } else if (_completeMajorMap[$(this).text()]["campus"] == _currentCampus) {
            appendTo = "#currentCampus";
        } else {
            appendTo ="#" + _completeMajorMap[$(this).text()]["campus"].toLowerCase() + "Campus";
        }
        $(appendTo).append(template({
            status: "checked",
            data: _completeMajorMap[$(this).text()]["major_full_nm"]
        }));
        $(appendTo + " li:last").data("code", $(this).text());
    });
    /* THIS BLOCK USED IF CURRENT SELECTIONS SHOWN AS PILLS BELOW SEARCH FIELD - IGNORE FOR NOW */
    /*$(".chosen_major").each(function() {
        var appendTo = "";
        if (_completeMajorMap[$(this).children(".code").text()]["college"] == $("#dropdownMenu:first-child").val())
            appendTo = "#selectedCollege";
        else if (_completeMajorMap[$(this).children(".code").text()]["campus"] == _currentCampus)
            appendTo = "#currentCampus";
        else appendTo ="#" + _completeMajorMap[$(this).children(".code").text()]["campus"].toLowerCase() + "Campus";
        $(appendTo).append("<li><a href='#'><input type='checkbox' checked/>&nbsp;" + _completeMajorMap[$(this).children(".code").text()]["major_full_nm"] + "</a></li>");
        $(appendTo + " li:last").data("code", $(this).children(".code").text());
    });*/
}

//Checks if multiple majors have been selected
function multipleSelected() {
    if ($(".chosen_major").length > 0)
        return true;
    else return false;
}

//Toggles the Go button if search enabled/disabled
function toggleGo() {
    if ($("#dropdownMenu:first-child").val() != "All" || $("#search").val().length > 0)
        $("#goBtn").removeClass("disabled");
    else $("#goBtn").addClass("disabled");
}

//Displays message when no results found anywhere in the UW major list
function noResults() {
    // Compile no-results Handlebars template
    var source = $("#no-results").html();
    var template = Handlebars.compile(source);
    $(".sample-data").css("display","none");
    $("#suggestions").css("display","none");
    $(".no-results-warning").css("display","block");
    if (multipleSelected())
        $(".no-results-warning").addClass("alert alert-info");
    $(".no-results-warning").html(template({
        search: $("input#search").val()
    }));
    $("#loadingModal").modal('hide');
}

//Displays message when no results found in selected college
function noResultsCollege(col) {
    // Compile no-results-college Handlebars template
    var source = $("#no-results-college").html();
    var template = Handlebars.compile(source);
    $(".sample-data").css("display","none");
    $("#suggestions").css("display","none");
    $(".no-results-warning").css("display","block");
    if (multipleSelected())
        $(".no-results-warning").addClass("alert alert-info");
    $(".no-results-warning").html(template({
        search: $("input#search").val(),
        college: col
    }));
}

//Item selection
function updateEvents() {
    // Compile update-events Handlebars template
    var source = $("#update-events").html();
    var template = Handlebars.compile(source);

    $("#suggestions li").hover(
        function () {
          $(this).parents("li").css({"background-color":"blue"});
        },
        function () {
          $(this).parents("li").css({"background-color":"white"});
        }
    );

    //Update selected majors when user clicks on suggested major
    $("#suggestions li, #suggestions a").click(function (e) {
        if (!$(e.target).is("input:checkbox")) {
            e.preventDefault();
            $(this).children("input:checkbox").prop("checked", !$(this).children("input:checkbox").prop("checked"));
        }
        var list = [];
        //var names = [];//USED FOR DISPLAYING SELECTIONS AS PILLS/PLACEHOLDERS
        var code = $(this).parent("li").data("code");

        if ($(this).children("input:checkbox").prop("checked")) {
            $(".selected").prepend(template({
                chosen: code
            }));
            _searchResultsChecked = true;
        } else {
            $(".chosen_major").each(function () {
                if ($(this).text() == code)
                    $(this).addClass("remove");
            });
            $(".remove").remove();
        }
        $(".chosen_major").each(function() {
            list.push($(this).text());
        });

        /* THIS BLOCK USED WHEN SELECTED MAJORS SHOWN AS PILL BELOW SEARCH FIELD - IGNORE FOR NOW */
        /*if ($(this).children("input:checkbox").prop("checked")) {
            $(".selected").append("<div class='chosen_major label label-default'><span class='code'>" + code + "</span>" + _completeMajorMap[code]["major_full_nm"] + "</div>");
        }
        else {
            $(".chosen_major").each(function () {
                if ($(this).children(".code").text() == code)
                    $(this).addClass("remove");
            })
            $(".remove").remove();
        }
        $(".chosen_major").each(function() {
            list.push($(this).children(".code").text());
            names.push(_completeMajorMap[$(this).children(".code").text()]["major_full_nm"]);

        });*/

        //TESTING SHOWING CURRENT SELECTIONS IN INPUT FIELD
        //$("#search").attr("placeholder",names.join(", "));

        //start timer to make suggestions box disappear after 3sec
        clearTimeout(_timer);
        _timer = setTimeout(hideSearchSuggestions, 3000);

        //Draw data table(s)
        createMajorCard(list, $("#compare").val());
    });
}

//hides search results and clears input when user clicks outside the results
$("html").click(function (e) {
    if ($("#suggestions").css("display") == "block" && !$(e.target).parents('div#suggestions').length && e.target.getAttribute("id") != 'search') {
       hideSearchSuggestions();
   }
});

//hides search results and clears input
function hideSearchSuggestions() {
    $("#suggestions").css("display","none");
    $("#search").val("");
    $("#search").blur();
}

//Search major list for text in input field
function goSearch() {
    // Compile update-events Handlebars template (shared)
    var source = $("#update-events").html();
    var template = Handlebars.compile(source);

    //First clear everything already shown then show all majors in college
    $("#loadingModal").modal('show');
    $("#boxplots").html("");
    var list = [];
    var results = false;

    var search = $("#search").val();
    var selectedCol = $("#dropdownMenu:first-child").val();
    console.log(search + ", " + selectedCol);
    var newMajors = "";
    //if any text in the search field and dropdown = All, show all matching majors + any that are currently selected
    if (search != "" && selectedCol == "All") {
        //Only if user has not made new selections
        if (!_searchResultsChecked) {
            $("#suggestions li.suggested_major").each(function() {
                newMajors += template({
                    chosen: $(this).data("code")
                });
            });
        }
        results = true;
    }
    //else if any text in search field and dropdown != All, show matching majors from that college - if no matching majors in that college: error message should make that clear... matching items in ul#selectedCollege
    else if (search != "" && selectedCol != "All") {
        //Add error message if nothing found
        if ($("#selectedCollege li.suggested_major").length == 0) {
            noResultsCollege(selectedCol);
            results = true; //not technically true but used to override generic error
        }
        else {
            //Only if user has not made new selections
            if (!_searchResultsChecked) {
                $("#selectedCollege li.suggested_major").each(function() {
                    newMajors += template({
                        chosen: $(this).data("code")
                    });
                });
            }
            results = true;
        }
    }
    //else if no text and dropdown != All... show all majors in college
    else if (search == "" && selectedCol != "All") {
        for (var maj in _completeMajorMap) {
            if (_completeMajorMap[maj]["college"] == selectedCol) {
                newMajors += template({
                    chosen: maj
                });
                /* THIS LINE USED TO SHOW CURRENT SELECTIONS AS PILLS BELOW SEARCH */
                /*$(".selected").append("<div class='chosen_major label label-default'><span class='code'>" + maj + "</span>" + _completeMajorMap[maj]["major_full_nm"] + "</div>");*/
            }
        }
        results = true;
    }
    $(".selected").prepend(newMajors);
    //store all selections
    $(".chosen_major").each(function() {
        if (list.indexOf($(this).text()) == -1)
            list.push($(this).text());
    });
    if (list.length > 0) {
        hideSearchSuggestions();
        setTimeout(createMajorCard(list),300);
    } else if (!results)
        noResults();
    else $("#loadingModal").modal('hide');
}


/*** COMPARE GPA MODULE ***/
//Adds the "Compare your GPA" module
function showCompareModule(gpa) {
    // Compile show-compare-module Handlebars template
    var source =  $("#show-compare-module").html();
    var template = Handlebars.compile(source);

    $("#header-row").append(template({
        gpa: gpa
    }));

    //only allow numbers and decimal point and delete/backspace
    $("#compare").keydown(function(e) {
        if (e.which == 13) {
            validateGPA();
            return false;
        }
    });

    $("#compareBtn").click(function(e) {
       validateGPA();
    });
}

//Check entered GPA is valid
function validateGPA() {
    //check GPA is under 4, round to 2 dp
    if (isNaN($("#compare").val()) || $("#compare").val() > 4 || $("#compare").val() < 1.5) {
        var source = $("#validate-gpa").html();
        var template = Handlebars.compile(source);
        //showGPA(null);
        $(".myGPA, #gpaLabel").remove();
        $("#compare").focus();
        $("#compare-msg").html(template({}));
    } else {
        showGPA(round(Number($("#compare").val()), 2));
    }
}

//Add GPA to boxplots
function showGPA(gpa) {
    //create major list from existing, pass gpa
    var list = [];
    $(".chosen_major").each(function() {
        list.push($(this).text());
    });
    //Draws data table(s)
    createMajorCard(list,gpa);
}

/**** MISC ****/
//redraw data table if window is resized
d3.select(window).on('resize', resizeCharts);

//Clears all data
$("#clear_majors").click(function(e) {
    $("#clear_majors").css("display","none");
    $(".chosen_major").remove();
    $(".no-results-warning").css("display","none");
    $(".no-results-warning").removeClass("alert alert-info");
    $("input#search").val("");
    $("#boxplots").html("");
    $(".yourgpa-box").remove();
    storeSelections(null);
});
