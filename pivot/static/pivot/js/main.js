//Functions shared by major and course pages

//Data storage
var _majorLookup = {};
var _completeMajorMap = [];
var _currentCampus = "Seattle";
var _timer;//Timer to hide search suggestions after period of inactivity - used in major.js

var _campusNameLookup = {};
var _majorNameLookup = {};
var _courseNameLookup = {};
var _statusLookup = {};
var update_results_on_load = false;
var all_data_loaded = false;
var _searchResultsChecked = false;

/**** SETUP ****/
if (window.location.search == "?slow") {
    window.setTimeout(function() { getDataNameMap(); }, 5000);
} else {
    getDataNameMap();
}

// initializes app
$(function () {
    // initializes bootstrap popover plugin
    $('[data-toggle="popover"]').popover();
    // initializes onboarding dialog
    initOnboardingDialog();
});

// checks local storage and initializes onboarding dialog
function initOnboardingDialog() {
    // check the session if modal has been temporarily dismissed
    var isTempForgotten = sessionStorage.getItem("isTempForgotten");
    // if isTempForgotten is anything other than null, then
    // then don't show the modal
    if (isTempForgotten == null) {
        // check if the modal has been permanently forgotten or not
        var isPermForgotten = localStorage.getItem("isPermForgotten");
        isPermForgotten = isPermForgotten == null ? false : isPermForgotten;
        // if the modal has not been permanently forgotten, show it
        if (isPermForgotten == false || isPermForgotten == "false") {
	     $("#onboard-modal").modal("show");
	     $("#perm-forget-modal").focus();
        } else {
            // set temp forgotten to represent forgotten state to
            // prevent execution of multiple if conditions
            sessionStorage.setItem("isTempForgotten", true);
        }
    }

    // add event listener when modal is dismissed
    // set isTempForgotten to prevent further modals during the session
    $("#onboard-modal").on("hidden.bs.modal", function() {
        sessionStorage.setItem("isTempForgotten", true);
    });

    $("#perm-forget-modal").on("click", function(){
        localStorage.setItem("isPermForgotten", true);
    });
}

/**** READ DATA FROM CSV ****/

//Reads file that maps data from course file to major file
function getDataNameMap() {
    d3.csv("/api/v1/data_map/", function(d) {
        return {
            is_course: d.is_course.trim(),
            is_major: d.is_major.trim(),
            is_campus: d.is_campus.trim(),
            name: d.name.trim(),
            id: d.id.trim(),
        };
    }, function(error, data) {
        for (var index in data) {
            if (parseInt(data[index]["is_course"])) {
                _courseNameLookup[data[index]["id"]] = data[index]["name"]
            }
            if (parseInt(data[index]["is_major"])) {
                _majorNameLookup[data[index]["id"]] = data[index]["name"]
            }
            if (parseInt(data[index]["is_campus"])) {
                _campusNameLookup[data[index]["id"]] = data[index]["name"]
            }
        }
        getCompleteMajorMap();
    });
}

//Reads major and course data file
function getCompleteMajorMap() {
    d3.csv("/api/v1/major_course/", function(d) {
        return {
            major_abbr: d.major_abbr.trim(),
            pathway: d.pathway.trim(),
            dept_abbrev: d.dept_abbrev.trim(),
            course_number: d.course_number.trim(),
            student_count: d.student_count.trim(),
            students_in_major: d.students_in_major.trim(),
            course_gpa_50pct: d.course_gpa_50pct.trim(),
            CourseLongName: _courseNameLookup[d.CourseLongName.trim()],
            major_full_nm: _majorNameLookup[d.major_full_nm.trim()],
            CoursePopularityRank: d.CoursePopularityRank.trim(),
            Campus: _campusNameLookup[d.Campus.trim()]
        };

    }, function(error, data) {
        var id = 0;
        for (var index in data) {
            var cID = data[index]["dept_abbrev"] + data[index]["course_number"];
            var major = data[index]["major_abbr"] + "-" + data[index]["pathway"];
            if (_completeMajorMap.hasOwnProperty(major)) {
                if (!_completeMajorMap[major]["courses"].hasOwnProperty(cID)) {
                    _completeMajorMap[major]["courses"][cID] = {
                        dept_abbrev: data[index]["dept_abbrev"],
                        course_number: data[index]["course_number"],
                        student_count: data[index]["student_count"],
                        course_long_name: data[index]["CourseLongName"],
                        popularity_rank: data[index]["CoursePopularityRank"],
                        percentiles: new Array(11)
                    }
                }
                _completeMajorMap[major]["courses"][cID]["percentiles"][5] = data[index]["course_gpa_50pct"];
            }
            else {
                _completeMajorMap[major] = {
                    id:id,
                    students_in_major: data[index]["students_in_major"],
                    major_full_nm: data[index]["major_full_nm"],
                    campus: data[index]["Campus"],
                    college: "",
                    courses: {}
                }
                _completeMajorMap[major]["courses"][cID] = {
                    dept_abbrev: data[index]["dept_abbrev"],
                    course_number: data[index]["course_number"],
                    student_count: data[index]["student_count"],
                    course_long_name: data[index]["CourseLongName"],
                    popularity_rank: data[index]["CoursePopularityRank"],
                    percentiles: new Array(11)
                }
                id++;
                _completeMajorMap[major]["courses"][cID]["percentiles"][5] = data[index]["course_gpa_50pct"];
            }
        }
        getMajorStatus();
        addStudents();
    });
}

//Reads seattle major status file
function getMajorStatus() {
    d3.csv("/api/v1/status_lookup/", function (d) {
        return {
            code: d.Code.trim(),
            url: d.URL.trim(),
            status: d.Status.trim()
        }
    }, function (error, data) {
        for (var index in data) {
            _statusLookup[data[index]["code"]] = {
                "url": data[index]["url"],
                "status": data[index]["status"]
            }
        }
    });
}

//Generates HTML to show major name, url and status (for major and course pages)
function displayMajorStatusURL(code) {
    var parts = code.split('-');
    var major_abbr = parts[0];
    if (myplan_alias[major_abbr]) {
	major_abbr = myplan_alias[major_abbr];
    }
    var url = "https://myplan.uw.edu/program/#/programs/UG-" + major_abbr + "-MAJOR";
    var msg = _completeMajorMap[code]["major_full_nm"];
    var source = $("#display-major-status-url").html();
    var template = Handlebars.compile(source);
    msg = template({
    	url: url,
        msg: msg
    });
    return msg;
}

function displayMajorStatusIcon(code) {
    var parts = code.split('-');
    var msg = "";
    if (_statusLookup.hasOwnProperty(parts[0])) {
        var title = _statusLookup[parts[0]]["status"];
        var url = images_paths[title];
        // Compile the Handlebar template
        var source = $("#display-major-status-icon").html();
        var template = Handlebars.compile(source);
        msg = template({
            src: url,
            title: title
        });
    }
    return msg;
}

function displayMajorStatusText(code) {
    var parts = code.split('-');
    var msg = "";
    if (_statusLookup.hasOwnProperty(parts[0]))
        msg = _statusLookup[parts[0]]["status"];
    return msg;
}

//Reads student data file
function addStudents() {
    d3.csv("/api/v1/student_data/", function (d) {
        return {
            major_abbr: d.major_abbr.trim(),
            pathway: d.pathway.trim(),
            college: d.College.trim(),
            count: d.count.trim(),
            iqr_min: d.iqr_min.trim(),
            q1: d.q1.trim(),
            median: d.median.trim(),
            q3: d.q3.trim(),
            iqr_max: d.iqr_max.trim(),
        }
    }, function (error, data) {
        for (var index in data) {
            var major = data[index]["major_abbr"] + "-" + data[index]["pathway"];

            if (!_majorLookup[major]) {
                _majorLookup[major] = data[index];
                try {
                    // Known failure - not all majors have course data
                    if (_completeMajorMap[major]) {
                        _completeMajorMap[major]["college"] = data[index]["college"];
                    }
                } catch (err) {
                    console.log(err);
                }

            }
        }
        populateCollegeDropdown();
        all_data_loaded = true;

        checkStoredData();
        init_search_events();

        if (update_results_on_load) {
            prepareResults();

        }
    });

}


function init_search_events() {
    /***SEARCH***/
    //When user clicks or tabs in to search field...
    $("#search").on("focus", function() {
        _searchResultsChecked = false;
        prepareResults();
    });

    //When user types in search field...
    $("#search").on("input", prepareResults);
    var search_elm = $("#search");

    //When user clicks on college dropdown menu, hide search suggestions
    $("#dropdownMenu").on("click", function(e) {
        $("#suggestions").css("display","none");

        // Set focus on the selected item
        window.setTimeout(function() {
            $("#college-dropdown>ul>li[aria-selected]>a").focus();
        }, 100);

    });

    //Keyboard navigation for search input field
    $("#search").keydown(function(e) {
        if (e.which == 40) { //down arrow key - go to first suggestion
            $("#suggestions li.suggested_major").first().focus();
        } else if (e.which == 38) //up arrow key - go to last suggestion
            $("#suggestions li.suggested_major").last().focus();
        else if (e.which == 13) { //enter key - search for keyword in input field
            goSearch();
        }
    });

    //Keyboard navigation for search suggestions/results box
    $("#suggestions").keydown(function(e) {
        clearTimeout(_timer); //cancel timer checking for inactivity
        if (e.which == 40) { //down arrow key
            e.preventDefault();
            if (!$("li.suggested_major:focus").next().is(".divider")) {
                if (!$("li.suggested_major:focus").is("#suggestions ul:last-child li.suggested_major:last-child"))
                    $("li.suggested_major:focus").next().focus();
                else ($("#suggestions li.suggested_major").first().focus());
            }
            else $("li.suggested_major:focus").parent("ul").next().children("li.suggested_major").first().focus();
        } else if (e.which == 38) { //up arrow key
            e.preventDefault();
            if (!$("li.suggested_major:focus").prev().is(".dropdown-header"))
                $("li.suggested_major:focus").prev().focus();
            else {
                if (!$("li.suggested_major:focus").is("#suggestions ul:first-child li.suggested_major:first-child"))
                    $("li.suggested_major:focus").parent("ul").prev().children("li.suggested_major").last().focus();
                else ($("#suggestions li.suggested_major").last().focus());
            }
        } else if (e.which == 32 || e.which == 13) { //select with space key
            e.preventDefault();
            $("li.suggested_major:focus").trigger("click");
        }
    });
}


//Create the areas of the search suggestions box - one area for the currently selected college (if any) and one for each campus
function prepareResults(e) {
    //close college dropdown menu if it is currently open
    if ($(".dropdown-menu").css("display") != "none") {
        $("#dropdownMenu").dropdown("toggle");
    }
    var source = $("#prepare-results").html();
    var template = Handlebars.compile(source);
    $("#suggestions").html(template({
        selected_campus: $("#dropdownMenu").val(),
        current_campus: _currentCampus
    }));
    //If a college is selected from the dropdown menu or text has been entered in the input field
    //if college selected, should show everything in college AND current selections
    if ($("#dropdownMenu").val() != "All" || $("#search").val().length > 0) {
        displayResults();
    } else if ($(".chosen_major").length > 0) { //If nothing has been entered in the text field, but the user has made selections
        showCurrentSelections();
    } else { //Nothing to display
        $("#suggestions").css("display","none");
    }
    toggleGo(); //Update the "go" button display
    finishResults(); //Display search suggestions
    updateEvents();
    // adding the number of majors in the selected college
    // to the dropdown menu.
    var raw_search = $("#search").val().replace('(','').replace(')','');
    if (raw_search == "") {
        var results = $('.suggested_major').length;
        var college_suggestions;
        if (results === 1) {
            college_suggestions = results + " result";
        } else {
            college_suggestions = results + " results";
        }
        document.getElementById("numResults").innerHTML = college_suggestions;
    }
}

//Hides unused placeholder areas in search suggestions
function finishResults() {
    // Compile the handlebar templates
    var source = $("#finish-results").html();
    var template = Handlebars.compile(source);
    var source_divider = $("#finish-results-divider").html();
    var template_divider = Handlebars.compile(source_divider);

    if ($("#dropdownMenu").val() == "All")
        $("#selectedCollege").remove();
    else {
        if (all_data_loaded && $("#selectedCollege li").length == 1 && $("#dropdownMenu").val() != "All") {
            $("#selectedCollege").append(template({
                message: "No matching major in this college"
            }));
        } else if ($("#selectedCollege li").length == 1 && $("#dropdownMenu").val() != "All") {
            $("#selectedCollege").append(template({
                message: "Loading..."
            }));
        }
        $("#selectedCollege").append(template_divider({}));
    }

    // Handle current campus
    if ($("#currentCampus li").length == 1) {
        $("#currentCampus").remove();
    } else {
        $("#currentCampus").append(template_divider({}));
    }

    // Handle bothell campus
    if ($("#bothellCampus li").length == 1) {
        $("#bothellCampus").remove();
    } else {
        $("#bothellCampus").append(template_divider({}));
    }

    // Handle seattle campus
    if ($("#seattleCampus li").length == 1) {
        $("#seattleCampus").remove();
    } else {
        $("#seattleCampus").append(template_divider({}));
    }

    // Handle tacoma campus
    if ($("#tacomaCampus li").length == 1) {
        $("#tacomaCampus").remove();
    } else {
        $("#tacomaCampus").append(template_divider({}));
    }

    $("#suggestions .divider").last().remove();
}

//Go button is pressed > search
$("#goBtn").click(function (e) {
    if (!$("#goBtn").hasClass("disabled"))
        goSearch();
});

/*** COLLEGE DROPDOWN ****/
//Called when data files have been read - populates college dropdown menu
function populateCollegeDropdown() {
    //Put colleges from _currentCampus first, otherwise alphabetical order
    var campuses = [];
    campuses.push(_currentCampus);
    if (campuses.indexOf("Bothell") == -1) {
        campuses.push("Bothell");
    }
    if (campuses.indexOf("Seattle") == -1) {
        campuses.push("seattle");
    }
    if (campuses.indexOf("Tacoma") == -1) {
        campuses.push("Tacoma");
    }

    $("#dropdownMenu").val("All");

    // Compile the handlebar template
    var source = $("#populate-college-dropdown").html();
    var template = Handlebars.compile(source);
    var campus_college = [];

    // Construct the dict to be used by the template
    for (var c = 0; c < campuses.length; c++) {
        var colleges = [];
        for (var maj in _completeMajorMap) {
            if (_completeMajorMap[maj]["campus"] == campuses[c] && colleges.indexOf(_completeMajorMap[maj]["college"]) == -1)
                colleges.push(_completeMajorMap[maj]["college"])
        }
        colleges.sort();
        campus_college.push({
            campus: campuses[c],
            colleges: colleges
        });
    }

    $("#college-dropdown .dropdown-menu").append(template({
        campus_college: campus_college
    }));

    //Show selection in button
    $("#college-dropdown .dropdown-menu li a").click(function(){
        // Remove the previously selected dropdown option
        var prev_selected = $("#college-dropdown .dropdown-menu .active");
        prev_selected.removeClass("active");
        prev_selected.removeAttr("aria-selected");

        // Visually select the clicked on option
        $(this).parent().addClass("active");
        $(this).parent().attr("aria-selected","true");

        var selection_source = $("#populate-college-dropdown-college-selection").html();
        var selection_template = Handlebars.compile(selection_source);

        $("#dropdownMenu").html(selection_template({college_selection: $(this).text()}));
        if ($(this).text() === "All Colleges") {
            $("#dropdownMenu").val("All");
        } else {
            $("#dropdownMenu").val($(this).text());
        }
        $("#dropdownMenu").attr("data-campus", $(this).attr("class"));
        toggleGo();
        if (window.location.href.indexOf("course-gpa") > -1) {
            // creates a user like click
            setTimeout(prepareResults, 10);
        }
        $( "#dropdownMenu" ).focus();
    });

    //If this is the course page and a code is provided, load the data without searching
    if (getParameterByName("code") != null) {
        listCoursesForMajor(getParameterByName("code").replace("_", " "));
        //TODO: need to update placeholders
    }

}

/**** MISC ****/

//Contact Advisor tab - NOTE: not in use for advisor beta but will be brought back if/when released to students
$("#contact").click(function(e) {
    //slide left and bring blurb
    if ($("#contact").css("right") == "0px") {
        $("#contact").animate({right:'300px'},350);
        $("#blurb").animate({right:'0px'}, 350);
    } else {
        $("#contact").animate({right:'0px'},350);
        $("#blurb").animate({right:'-300px'}, 350);
    }
});

//Get url paramters
function getParameterByName(name, url) {
    if (!url) url = window.location.href;
    name = name.replace(/[\[\]]/g, "\\$&");
    var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)"),
        results = regex.exec(url);
    if (!results) return null;
    if (!results[2]) return '';
    return decodeURIComponent(results[2].replace(/\+/g, " "));
}

//rounds to the specified decimal place
function round(value, decimals) {
    return value.toFixed(decimals);
}

function clearCommonSelection() {
    $("#clear_majors").css("display","none");
    $(".chosen_major").remove();
    $(".no-results-warning").css("display","none");
    $(".protected-result-warning").css("display","none");
    $("input#search").val("");
    $(".results-section").css("display","none");
    $(".sample-data").css("display","block");
    clearCollegeSelection();
}

function clearCollegeSelection() {
    var source = $("#populate-college-dropdown-college-selection").html();
    var template = Handlebars.compile(source);
    $("#dropdownMenu").html(template({college_selection: "All"}));
    $("#dropdownMenu").val("All");
    // Remove the previously selected dropdown option
    var prev_selected = $("#college-dropdown .dropdown-menu .active");
    prev_selected.removeClass("active");
    prev_selected.removeAttr("aria-selected");

    // Visually select the first option (All)
    $("#college-dropdown .dropdown-menu li").first().addClass("active");
    $("#college-dropdown .dropdown-menu li").first().attr("aria-selected","true");
}

// Adding the popover for the capacity description links
function addCapacityDescription(id, location) {
    var source = $("#admission-type-help-popover").html();
    var template = Handlebars.compile(source);
    var clear_id = id.replace("_", " ");

    if (location == "major") {
       $("#" + id + " #major-status-Help").popover({
            trigger: "focus",
            placement: "top",
            html: true,
            container: "#" + id,
                   content: template({
                major_status_text: displayMajorStatusText(clear_id)
            })
        });
   } else if (location == "course") {
       $("#major-status-Help").popover({
            trigger: "focus",
            placement: "top",
            html: true,
            container: "body",
            content: template({
                major_status_text: displayMajorStatusText(clear_id)
            })
        });
   }
}

/* The following functions display the number of current 
   suggestions in the dropdown search menu */
function doneTyping() {
    var suggestion_text;
    var raw_search = $("#search").val().replace('(','').replace(')','');
    // Number of suggestions currently listed in dropdown
    num_suggestions = $('.suggested_major').length;

    if (num_suggestions === 1) {
        suggestion_text = num_suggestions + " result for '" + raw_search + "'";
    } else {
        suggestion_text = num_suggestions + " results for '" + raw_search + "'";
    }
    document.getElementById("numResults").innerHTML = suggestion_text;
}

var typingTimer;
var doneTypingInterval = 1000; // time in milliseconds

// Initiates the doneTyping function whenever
// the user is finished typing in the search box,
// and the time reaches the doneTypingInterval
$('#search').on('keyup.num focus.num', function(e){
    clearTimeout(typingTimer);
    if ($('#search').val()) {
        typingTimer = setTimeout(doneTyping, doneTypingInterval);
    }
});

//NOT IN USE? checks last digit after decimal places, returns true if trailing zero
/*function trailingZero(value) {
 if (value != null) {
 var str = value.toString();
 if(/\d+(\.\d+)?/.test(str)) {
 var lastNum = parseInt(str[str.length - 1]);
 return (lastNum==0);
 }
 }
 return true;
 }*/
