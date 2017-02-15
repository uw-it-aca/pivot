//Functions specific to the course tab

/**** SETUP ****/
//If major was already loaded (this session), automatically load it again
function checkStoredData() {
    var paramCode = getParameterByName("code");
    if (sessionStorage.getItem("courses") != null && paramCode == null) {
        listCoursesForMajor(sessionStorage.getItem("courses"));
    } else if (paramCode != null) {
        listCoursesForMajor(paramCode.replace("_", " "));
    } else $(".sample-data").css("display","block");
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
            var majText = _completeMajorMap[maj]["major_full_nm"].replace(new RegExp("\\b" + search_val, "ig"), "<b>" + substring + "</b>");
            $(appendTo).append(template({major: majText}));
            $(appendTo + " li:last").data("code", maj);
            count++;
        }
        //else if nothing has been entered but a college is selected, load all majors in college
        else if (search_val.length == 0 && _completeMajorMap[maj]["college"] == $("#dropdownMenu:first-child").val()) {
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
    }
    else if ($("#currentCampus li.suggested_major").length == 1 && selectedCol == "All") {
       maj = $("#currentCampus li.suggested_major").data("code");
    }
    else if (selectedCol != "All" && $("#selectedCollege li.suggested_major").length == 1)
        maj = $("#selectedCollege li.suggested_major").data("code");
    else if ($("#suggestions li.suggested_major").length > 1)
        multipleResults();
    else noResults();
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
    $(".no-results-warning").html("<p><b>Multiple results found for keyword \"" + $("input#search").val() + "\" in UW major list.</b></p><p>Select a single major. Refer to the list of undergraduate majors in <a href='http://www.washington.edu/uaa/advising/academic-planning/majors-and-minors/list-of-undergraduate-majors/' target='_blank'>Seattle</a>, <a href='http://www.uwb.edu/academics' target='_blank'>Bothell</a>, and <a href='http://www.tacoma.uw.edu/uwt/admissions/undergraduate-majors' target='_blank'>Tacoma</a>.</p>");
}

//Hides the suggestion box if user clicks outside it
$("html").click(function (e) {
    if ($("#suggestions").css("display") == "block" && !$(e.target).parents('div#suggestions').length && e.target.getAttribute("id") != 'search') {
       closeSuggestions();
   }
});

/**** SHOW COURSE DATA ****/
//Creates and displays the course data
function listCoursesForMajor(maj) {
    //updates the session storage for selected major
    sessionStorage.setItem("courses", maj);

    //Hide sample data, replace other major data, clear any warnings
    $(".sample-data").css("display","none");
    $("#courselist").html("");
    $("#clear_majors").css("display","inline");
    $(".results-section").css("display","inline");
    $(".no-results-warning").css("display", "none");

    //maj = major code A A-0
    var id = maj.replace(" ","_");
    var h = "<div class='course-card row' id='" + id + "'><p class='college-heading'>" + _completeMajorMap[maj]["college"] + " - " + _completeMajorMap[maj]["campus"] + " campus</p><div class='col-xs-9'><h3 class='major-heading-course'>" + displayMajorStatusURL(maj) + "</h3>"
+ "<div class='major-gpa-line'>  " + displayMajorStatusIcon(maj) + "   " + displayMajorStatusText(maj) + " <span class='gpa-small'>  Median GPA: " + round(Number(_majorLookup[maj]["median"]), 2) + " </span></div>"
    +"</div>"
    + "</div></div></p><div class='col-xs-10'><table class='table table-striped'><thead><tr><th><p class='data-heading'>% <a class='inlineHelp' id='percentHelp' tabindex='0' role='button' data-toggle='popover' data-trigger='focus' data-content=''><span class='glyphicon glyphicon-info-sign' aria-hidden='true'></span></a></p></th><th><p class='data-heading'>Code</p></th><th><p class='data-heading'>Most Commonly Taken Courses</p></th><th><p class='data-heading'>Median Course Grade <a class='inlineHelp' id='courseGradeHelp' tabindex='0' role='button' data-toggle='popover' data-trigger='focus' data-content=''><span class='glyphicon glyphicon-info-sign' aria-hidden='true'></span></a></p></th></tr></thead><tbody>";
    var courses = _completeMajorMap[maj]["courses"];
    var ct = 0;//show 10 max
    for (var c in courses) {
        if (ct < 10) {
            var popularity = Math.round((courses[c]["student_count"] / _completeMajorMap[maj]["students_in_major"]) * 100) + "%";
            var col = "q" + colorBucket(courses[c]["percentiles"][5])+ "-9";
            h+= "<tr><td><p>" + popularity + "</p></td><td><p class='coursecode'>" + courses[c]["dept_abbrev"] + " " + courses[c]["course_number"] + "</p></td><td><p>" + courses[c]["course_long_name"] + "</p></td><td><p class='course-median course-table-row " + col + "'>" + round(parseFloat(courses[c]["percentiles"][5]),2) + "</p></td></tr>";
            ct++;
        } else break;
    }
    h += "</tbody></table></div><div class='col-xs-2 panel panel-default bar-legend'><p>Color Legend:</p><div id='color-legend'>"
    + "<div class='q0-9 color-block'></div><div class='bar-legend-0'> 1.50 to 1.99</div>"
    + "<div class='q1-9 color-block'></div><div class='bar-legend-0'> 2.00 to 2.49</div>"
    + "<div class='q2-9 color-block'></div><div class='bar-legend-0'> 2.50 to 2.99</div>"
    + "<div class='q3-9 color-block'></div><div class='bar-legend-0'> 3.00 to 3.49</div>"
    + "<div class='q4-9 color-block'></div><div class='bar-legend-0'> 3.50 to 4.00</div>"
    + "<div class='q9-9 color-block'>"
    ;
    $("#courselist").append(h);
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

//Clears all data
$("#clear_majors").click(function(e) {
    $("#clear_majors").css("display","none");
    $(".chosen_major").remove();
    $(".no-results-warning").css("display","none");
    $("input#search").val("");
    $("#courselist").html("");
});

//returns the ColorBrewer bucket index for the given GPA
function colorBucket(gpa) {
    var min = 1.5
    var max = 4.0
    var div = (4.0 - 1.5) / 5;//9;
    for (var i = 1; i < 6; i++) {
        if (gpa > 1.5 + div * (i - 1) && gpa <= 1.5 + div * i)
            /*if ((i-1)%2 == 0)
                return i - 1;
            else*/ return i-1;
    }
    return 0;
}
