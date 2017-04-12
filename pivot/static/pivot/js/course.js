//Functions specific to the course tab

/**** SETUP ****/
//If major was already loaded (this session), automatically load it again
function checkStoredData() {
    var paramCode = getParameterByName("code");
    if (paramCode != null) {
        listCoursesForMajor(paramCode.replace("_", " "));
    } else if (sessionStorage.length > 0 && sessionStorage.getItem("courses") != null && sessionStorage.getItem("courses") != "null") {
        listCoursesForMajor(sessionStorage.getItem("courses"));
    } else {
        $(".sample-data").css("display","block");
    }
}

/***SEARCH***/

//Item selection
function updateEvents() {
    $("#suggestions li").hover(
        function () {
          $(this).parents("li").css({"background-color":"blue"});
        },
        function () {
          $(this).parents("li").css({"background-color":"white"});
        }
    );


    $("#suggestions li, #suggestions a").click(function (e) {
        e.preventDefault();
        var list = [];
        var code = $(this).parent("li").data("code");
        if (code != undefined) {
            var selected = false;
            $(".chosen_major").each(function () {
                if ($(this).text() == code) {
                    //major already selected, just hide suggestions and return
                    selected = true;
                    return;
                }
            });
            if (!selected) {
                var source = $("#update-events").html();
                var template = Handlebars.compile(source);
                $(".selected").html(template({chosen: code}));
                //FOR MULTIPLE SELECTIONS $(".selected").append("<div class='chosen_major'>" + code + "</div>");
            }
            $(".chosen_major").each(function() {
                list.push($(this).text());
                $("#loadingModal").modal('show');
                setTimeout(listCoursesForMajor($(this).text()), 300);
            });
            closeSuggestions();
        }
    });
}


//Displays majors matching search term in the search suggestions
function displayResults() {
    $("#suggestions").css("display","block");
    var source = $("#display-results").html();
    var template = Handlebars.compile(source);

    var count = 0;
    var search_val = $("#search").val().toLowerCase().replace('(','').replace(')','');
    for(var maj in _completeMajorMap) {
        var index = _completeMajorMap[maj]["major_full_nm"].toLowerCase().indexOf(search_val);
        if (search_val.length > 0 && index > -1 && (index == 0 || _completeMajorMap[maj]["major_full_nm"].toLowerCase().charAt(index - 1) == " " || _completeMajorMap[maj]["major_full_nm"].toLowerCase().charAt(index - 1) == "(")) {
            //Find substring matching search term to make bold
            var substring = _completeMajorMap[maj]["major_full_nm"].substr(index, search_val.length);
            var appendTo = "";
            if (_completeMajorMap[maj]["college"] == $("#dropdownMenu:first-child").val() && _completeMajorMap[maj]["campus"] == $("#dropdownMenu:first-child").attr("data-campus"))
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
            var majText = _completeMajorMap[maj]["major_full_nm"].replace(new RegExp("\\b" + search_val, "ig"), "<b>" + substring + "</b>");
            $(appendTo).append(template({major: majText}));
            $(appendTo + " li:last").data("code", maj);
            count++;
        }
        //else if nothing has been entered but a college is selected, load all majors in college
        else if (search_val.length == 0 && _completeMajorMap[maj]["college"] == $("#dropdownMenu:first-child").val() && _completeMajorMap[maj]["campus"] == $("#dropdownMenu:first-child").attr("data-campus")) {
            var majText = _completeMajorMap[maj]["major_full_nm"];
            $("#selectedCollege").append(template({major: majText}));
            $(appendTo + " li:last").data("code", maj);
            count++;
        }
    }
    if (count == 0 && search_val.length > 0) {
        if (all_data_loaded) {
            noResults();
            return;
        }

        // If we're still loading data, show that we're loading...
        update_results_on_load = true;
    }
}

//Shows any currently selected majors in the search suggestions
function showCurrentSelections() {
    $("#suggestions").css("display","block");
    var source = $("#display-results").html();
    var template = Handlebars.compile(source);

    $(".chosen_major").each(function() {
        var appendTo = "";
        if (_completeMajorMap[$(this).text()]["college"] == $("#dropdownMenu:first-child").val()) {
            appendTo = "#selectedCollege";
        } else if (_completeMajorMap[$(this).text()]["campus"] == _currentCampus) {
            appendTo = "#currentCampus";
        } else {
            appendTo ="#" + _completeMajorMap[$(this).text()]["campus"].toLowerCase() + "Campus";
        }
        var majText = _completeMajorMap[$(this).text()]["major_full_nm"];
        $(appendTo).append(template({major: majText}));
        $(appendTo + " li:last").data("code", $(this).text());
    });
}

//Hide the search suggestions box
function closeSuggestions() {
   $("#suggestions").css("display","none");
   $("#search").val("");
   $("#search").blur();
}

//Toggles the Go button if search enabled/disabled
function toggleGo() {
    var selectedCol = $("#dropdownMenu:first-child").val();
    if (($("#suggestions li.suggested_major").length == 1 && selectedCol == "All") || ($("#currentCampus li.suggested_major").length == 1 && selectedCol == "All") || (selectedCol != "All" && $("#selectedCollege li.suggested_major").length == 1))
        $("#goBtn").removeClass("disabled");
    else $("#goBtn").addClass("disabled");
}

//Search the major list for text in input field
function goSearch() {
    //This should only work if a single major matches, otherwise error message
    $("#courseList").html("");
    var search = $("#search").val();
    var selectedCol = $("#dropdownMenu:first-child").val();
    var maj = "";
    //if there is one exact match or multiple matches but 1 in the current campus, show the courses for that major
    if ($("#suggestions li.suggested_major").length == 1 && selectedCol == "All") {
        maj = $("#suggestions li.suggested_major").data("code");
    } else if ($("#currentCampus li.suggested_major").length == 1 && selectedCol == "All") {
        maj = $("#currentCampus li.suggested_major").data("code");
    } else if (selectedCol != "All" && $("#selectedCollege li.suggested_major").length == 1) {
        maj = $("#selectedCollege li.suggested_major").data("code");
    } else if ($("#suggestions li.suggested_major").length > 1) {
        multipleResults();
    } else {
        noResults();
    }

    if (maj != "") {
        closeSuggestions();
        $("#loadingModal").modal('show');
        setTimeout(listCoursesForMajor(maj), 300);
    }
}

//Displays message when no results found
function noResults() {
    $(".sample-data").css("display","none");
    $("#suggestions").css("display","none");
    $(".no-results-warning").css("display","inline");
    var source = $("#no-results").html();
    var template = Handlebars.compile(source);
    var search_key = $("input#search").val();
    $(".no-results-warning").html(template({search: search_key}));

}

//Displays message when multiple results found - only one major can be selected at a time
function multipleResults() {
    $(".sample-data").css("display","none");
    $("#suggestions").css("display","none");
    $(".no-results-warning").css("display","inline")
    var source = $("#multiple-results").html();
    var template = Handlebars.compile(source);
    var search_key = $("input#search").val();
    $(".no-results-warning").html(template({search: search_key}));
}

//Hides the suggestion box if user clicks outside it
$("html").click(function (e) {
    if ($("#suggestions").css("display") == "block" && !$(e.target).parents('div#suggestions').length && e.target.getAttribute("id") != 'search') {
       closeSuggestions();
   }
});
//hides search results and clears input when user presses the esc key
$("html").keydown(function (e) {
    if (e.which == 27)
        closeSuggestions();
});

/**** SHOW COURSE DATA ****/
//Creates and displays the course data
function listCoursesForMajor(maj) {
    //updates the session storage for selected major
    storeSelections(maj);

    //Hide sample data, replace other major data, clear any warnings
    $(".sample-data").css("display","none");
    $("#courselist").html("");
    $("#clear_majors").css("display","inline");
    $(".results-section").css("display","inline");
    $(".no-results-warning").css("display", "none");

    //maj = major code A A-0
    var id = maj.replace(" ","_");

    // Compile the dynamic table data and pass it as a variable to outer template.
    var courses = _completeMajorMap[maj]["courses"];
    var count = 0;
    // Create a list of all the inner table data
    var inner_table_data = [];
    for (var c in courses) {
        // Show only upto 10 results
        if (count < 10) {
            var popularity = Math.round((courses[c]["student_count"] / _completeMajorMap[maj]["students_in_major"]) * 100) + "%";
            var col = "q" + colorBucket(courses[c]["percentiles"][5])+ "-9";
            var percentile = round(parseFloat(courses[c]["percentiles"][5]), 2);
            // Create a dict of all single line data and push it to the list
            var collection = {
                popularity: popularity,
                dept_abbrev: courses[c]["dept_abbrev"],
                course_number: courses[c]["course_number"],
                course_long_name: courses[c]["course_long_name"],
                col: col,
                percentile: percentile
            };
            inner_table_data.push(collection);
            count++;
        } else {
            break;
        }
    }

    // Compile the outer body with this.
    var source = $("#list-courses-for-major-outer").html();
    var template = Handlebars.compile(source);
    $("#courselist").append(template(
        {
            id: id,
            college: _completeMajorMap[maj]["college"],
            campus: _completeMajorMap[maj]["campus"],
            major_status_url: displayMajorStatusURL(maj),
            major_status_icon: displayMajorStatusIcon(maj),
            major_status_text: displayMajorStatusText(maj),
            median_gpa: round(Number(_majorLookup[maj]["median"]), 2),
            inner_table_data: inner_table_data
        }
    ));

    $("#percentHelp").popover({
        placement: "top",
        html: true,
        container: "body",
        content: "<p>Percent of students who had taken the course by the time they declared for the major that you've selected.</p>"
    });
    $("#courseGradeHelp").popover({
        placement: "top",
        html: true,
        container: "body",
        content: "<p>Median course grade of students who had taken the course by the time they declared for the major that you've selected.</p>"
    });
    $("#loadingModal").modal('hide');
}

// Stores courses in sessionStorage to pass between pages
function storeSelections(courses) {
    sessionStorage.setItem("courses", courses);
}

//Clears all data
$("#clear_majors").on("click", function(e) {
    $("#clear_majors").css("display","none");
    $(".chosen_major").remove();
    $(".no-results-warning").css("display","none");
    $("input#search").val("");
    $("#courselist").html("");
    $(".results-section").css("display", "none");
    storeSelections(null);
});

//returns the ColorBrewer bucket index for the given GPA
function colorBucket(gpa) {
    var min = 1.5
    var max = 4.0
    var div = (4.0 - 1.5) / 5; //9;
    for (var i = 1; i < 6; i++) {
        if (gpa > 1.5 + div * (i - 1) && gpa <= 1.5 + div * i) {
            /*if ((i-1)%2 == 0)
                return i - 1;
            else*/
            return i-1;
        }
    }
    return 0;
}
