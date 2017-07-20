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
        console.log("code=" + code);
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
                //$("#loadingModal").modal('show');
                setTimeout(listCoursesForMajor($(this).text()), 300);
            });
            $("#suggestions").css("display","none");
            clearTimeout(_timer);
            //closeSuggestions();
        }
    });
    
    //for the benefit of mobile devices trying to read a long suggestion list
    window.addEventListener("scroll", function() {
        if ($("#suggestions").css("display") == "block") {
            //start timer to make suggestions box disappear after 3sec
            clearTimeout(_timer);
            _timer = setTimeout(hideCourseSearchSuggestions, 3000);
            //_timer = setTimeout(hideSearchSuggestions, 3000);
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
    count = findSearchText($("#search").val(), template);
    if (search_val.length == 0 && $("#dropdownMenu:first-child").val() != "All") {
        for(var maj in _completeMajorMap) {
            if (_completeMajorMap[maj]["college"] == $("#dropdownMenu:first-child").val() && _completeMajorMap[maj]["campus"] == $("#dropdownMenu:first-child").attr("data-campus")) {
                var appendTo = "#selectedCollege";
                var majText = _completeMajorMap[maj]["major_full_nm"];
                $("#selectedCollege").append(template({major: majText}));
                $(appendTo + " li:last").data("code", maj);
                count++;
            }
        }
    }
    else if (count == 0 && search_val.length > 0) {
        if (all_data_loaded) {
            noResults();
            return;
        }
        // If we're still loading data, show that we're loading...
        update_results_on_load = true;
    } else {
        //start timer to make suggestions box disappear after 3sec
        clearTimeout(_timer);
        _timer = setTimeout(hideCourseSearchSuggestions, 3000);
        //_timer = setTimeout(hideSearchSuggestions, 3000);
    }
}

//looks for the search string in major full names
function findSearchText(orig_val, template) {
    //1. remove parentheses from the search term and make it lowercase
    var search_val = $("#search").val().toLowerCase().replace('(','').replace(')','');
    var words = search_val.split(" ");
    var count = 0;
    for (var maj in _completeMajorMap) {
        var allFound = false;
        var majText = _completeMajorMap[maj]["major_full_nm"];
        for (var word in words) {
            if (words[word].length > 0) {
                var index = _completeMajorMap[maj]["major_full_nm"].toLowerCase().indexOf(words[word]);
                if (index > -1 && (index == 0 || _completeMajorMap[maj]["major_full_nm"].toLowerCase().charAt(index - 1) == " " || _completeMajorMap[maj]["major_full_nm"].toLowerCase().charAt(index - 1) == "(")) {
                    allFound = true;
                    var substring = _completeMajorMap[maj]["major_full_nm"].substr(index, words[word].length);
                    var appendTo = "";
                    if (_completeMajorMap[maj]["college"] == $("#dropdownMenu:first-child").val() && _completeMajorMap[maj]["campus"] == $("#dropdownMenu:first-child").attr("data-campus"))
                        appendTo = "#selectedCollege";
                    else if (_completeMajorMap[maj]["campus"] == _currentCampus)
                        appendTo = "#currentCampus";
                    else appendTo ="#" + _completeMajorMap[maj]["campus"].toLowerCase() + "Campus";
                    majText = majText.replace(new RegExp("\\b" + words[word], "ig"), "<b>" + substring + "</b>");
                } else {
                    //A word is missing from the current major, stop looking at this major
                    allFound = false;
                    break;
                }
            }
        }
        if (allFound) {
            $(appendTo).append(template({major: majText}));
            $(appendTo + " li:last").data("code", maj);
            count++;
        }
    }
    return count;
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

//Close the suggestion tray and display the currently selected major in the search field
//If nothing selected, clear the field
function hideCourseSearchSuggestions() {
    $("#suggestions").css("display", "none");
    $(".chosen_major").each(function() {
        $("#search").val(_completeMajorMap[$(this).text()]["major_full_nm"]);
    });
    if (sessionStorage.getItem("courses") != null) {
        $("#search").val(_completeMajorMap[sessionStorage.getItem("courses")]["major_full_nm"]);
        $("#goBtn").removeClass("disabled");
    } else {
        $("#search").val("");
        $("#search").blur();
        $("#goBtn").addClass("disabled");
    }
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
    } 
    else if (search == _completeMajorMap[sessionStorage.getItem("courses")]["major_full_nm"]) {
        maj = sessionStorage.getItem("courses");
    }
    else if ($("#suggestions li.suggested_major").length > 1) {
        multipleResults();
    } else {
        noResults();
    }

    if (maj != "") {
        $("#suggestions").css("display","none");
        clearTimeout(_timer);
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
       hideCourseSearchSuggestions();//closeSuggestions();
   }
});
//hides search results and clears input when user presses the esc key
$("html").keydown(function (e) {
    if (e.which == 27)
        hideCourseSearchSuggestions();//closeSuggestions();
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
    
    //Display major name in search field & enable search button
    $("#search").val(_completeMajorMap[maj]["major_full_nm"]);
    $("#goBtn").removeClass("disabled");

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
    //$("#loadingModal").modal('hide');
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
