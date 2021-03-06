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

//a list of listeners waiting for the response
var statusLookupListener = [];

/**** SETUP ****/
if (window.location.pathname != "/about/" && window.location.pathname != "/login/") {
    //indexOf will return a -1 if it doesn't find the string. ~ will take the bitwise not of the
    //result, which will only be falsy if it is -1.
    getDataNameMap(window.location.search);
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
            // focus the close button once the modal is shown
            $("#onboard-modal").on("shown.bs.modal", function () {
                $("#close-modal-btn-top").focus();
            });
            $("#onboard-modal").modal("show");
        } else {
            // set temp forgotten to represent forgotten state to
            // prevent execution of multiple if conditions
            sessionStorage.setItem("isTempForgotten", true);
        }
    }

    // Loop the tabbing on the modal, if we get to the last
    // tabbable element and someone presses tab, go back up to the top
    $("#perm-forget-modal").on('keydown', function(e) {
        var keyCode = e.keyCode || e.which;
        if (keyCode === 9) {
            e.preventDefault();
            $("#close-modal-btn-top").focus();
        }
	});

    // add event listener when modal is dismissed
    // set isTempForgotten to prevent further modals during the session
    // Restore focus to the main content
    $("#onboard-modal").on("hidden.bs.modal", function() {
        sessionStorage.setItem("isTempForgotten", true);
        $("#shortcut").focus();
    });

    $("#perm-forget-modal").on("click", function(){
        localStorage.setItem("isPermForgotten", true);
    });
}

/**** READ DATA FROM CSV ****/

//Reads file that maps data from course file to major file
function getDataNameMap(queryStr) {
    $(".loader").css("display", "block");
    queryStr = queryStr || "";
    d3.csv("/api/v1/data_map/" + queryStr, function(d) {
        return {
            is_course: d.is_course.trim(),
            is_major: d.is_major.trim(),
            is_campus: d.is_campus.trim(),
            name: d.name.trim(),
            id: d.key.trim(),
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
        getCompleteMajorMap(queryStr);
    });
}

//Reads major and course data file
function getCompleteMajorMap(queryStr) {
    queryStr = queryStr || "";
    d3.csv("/api/v1/major_course/" + queryStr, function(d) {
        return {
            major_abbr: d.major_path.trim(),
            course_number: d.course_num.trim(),
            student_count: d.student_count.trim(),
            students_in_major: d.students_in_major.trim(),
            course_gpa_50pct: d.course_gpa_50pct.trim(),
            CourseLongName: _courseNameLookup[d.course_num.trim()],
            major_full_nm: _majorNameLookup[d.major_path.trim()],
            CoursePopularityRank: d.course_popularity_rank.trim(),
            Campus: _campusNameLookup[d.campus.trim()]
        };

    }, function(error, data) {
        var id = 0;
        for (var index in data) {
            var major = data[index]["major_abbr"].replace(/_/g, "-");

            // Format of a course_number is MATH_126, splitting it into MATH and 126
            var splitIndex = data[index]["course_number"].lastIndexOf("_");
            var dept_abbrev = data[index]["course_number"].substring(0, splitIndex);
            var course_number = data[index]["course_number"].substring(splitIndex + 1);
            var cID = dept_abbrev + course_number;

            if (_completeMajorMap.hasOwnProperty(major)) {
                if (!_completeMajorMap[major]["courses"].hasOwnProperty(cID)) {
                    _completeMajorMap[major]["courses"][cID] = {
                        dept_abbrev: dept_abbrev,
                        course_number: course_number,
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
                    id:course_number,
                    students_in_major: data[index]["students_in_major"],
                    major_full_nm: data[index]["major_full_nm"],
                    campus: data[index]["Campus"],
                    college: "",
                    courses: {}
                }
                _completeMajorMap[major]["courses"][cID] = {
                    dept_abbrev: dept_abbrev,
                    course_number: course_number,
                    student_count: data[index]["student_count"],
                    course_long_name: data[index]["CourseLongName"],
                    popularity_rank: data[index]["CoursePopularityRank"],
                    percentiles: new Array(11)
                }
                id++;
                _completeMajorMap[major]["courses"][cID]["percentiles"][5] = data[index]["course_gpa_50pct"];
            }
        }
        getMajorStatus(queryStr);
        addStudents(queryStr);
    });
}

//Reads seattle major status file
function getMajorStatus(queryStr) {
    queryStr = queryStr || "";
    d3.csv("/api/v1/status_lookup/" + queryStr, function (d) {
        return {
            code: d.code.trim(),
            name: _majorNameLookup[d.code.trim()],
            status: d.status.trim(),
            num_qtrs: d.quarters_of_data.trim()
        }
    }, function (error, data) {
        for (var index in data) {
            var code = data[index]["code"].replace(/_/g, "-");
            _statusLookup[code] = {
                "status": data[index]["status"],
                "name": data[index]["name"],
                "num_qtrs": data[index]["num_qtrs"],
            }
        }
        //call any listeners that were waiting on this request
        if (statusLookupListener.length > 0) {
            statusLookupListener.map(function (listener) {
                listener();
            });
        };
    });
}

//Generates HTML to show major name, url and status (for major and course pages)
function displayMajorStatusURL(code) {
    var parts = code.split(/-(?=(\d))/);
    var major_abbr = parts[0].replace('-', ' ');
    if (myplan_alias[major_abbr]) {
	   major_abbr = myplan_alias[major_abbr][0];
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
    var msg = "";
    if (_statusLookup.hasOwnProperty(code)) {
        var title = _statusLookup[code]["status"];
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
    var msg = "";
    if (_statusLookup.hasOwnProperty(code))
        msg = _statusLookup[code]["status"];
        msg = msg.charAt(0) + msg.slice(1);
        if (msg === "minimumRequirements") {
            msg = "minimum";
        }
    return msg;
}

//Reads student data file
function addStudents(queryStr) {
    queryStr = queryStr || "";
    d3.csv("/api/v1/student_data/" + queryStr, function (d) {
        return {
            major_abbr: d.major_path.trim(),
            college: d.college.trim(),
            count: d.count.trim(),
            iqr_min: d.iqr_min.trim(),
            q1: d.q1.trim(),
            median: d.median.trim(),
            q3: d.q3.trim(),
            iqr_max: d.iqr_max.trim(),
        }
    }, function (error, data) {
        for (var index in data) {
            var major = data[index]["major_abbr"].replace(/_/g, "-");

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

        if (window.location.pathname == '/major-gpa/' && getParameterByName("code") != null) {
            var majorParam = getParameterByName("code").split(",");
            var validCodes = [];
            var invalidCodes = [];

            for (var i in majorParam) {
                var major = majorParam[i].trim();
                if (major.length > 0) {
                    if (_statusLookup.hasOwnProperty(major)) {
                        validCodes.push('"' + major + '"');
                    } else {
                        invalidCodes.push(major);
                    }
                }
            }

            if (invalidCodes.length > 0) {
                $(".invalid-major-code-warning").css("display", "inline")
                var source = $("#invalid-major-code-warning").html();
                var template = Handlebars.compile(source);
                $(".invalid-major-code-warning").html(template({codes: invalidCodes.join(', '), plural: invalidCodes.length > 1}))
            }
            
            var selectedMajors = '[' + validCodes.join(',') + ']';
            
            sessionStorage.setItem("majors", selectedMajors);
        }

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
        //test if the text is an error messae
        var search_val = $("#search").val();
        var placeholder = /[0-9]+\smajor[s]*\sselected/.test(search_val);
        if (placeholder || window.location.pathname == "/course-gpa/") {
            $("#search").val("");
        }
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
            $("#college-dropdown>ul>li[aria-selected]").focus();
        }, 100);

    });

    //disable bootstrap default keyboard navingation
    $(document).off("keydown.dropdown.data-api");

    //arrow key navigation for dropdown menu
    $(".dropdown-menu").keydown(function (e) {
        if (e.which == 40 || e.which == 39) { //down or right arrow key {
            var allFocused = $("*").has(":focus").addBack(":focus");
            var curFocused = $(
                allFocused.filter(".college-list")[0] || //college focused?
                allFocused.filter(".dropdown-header")[0] || //campus focused?
                allFocused.filter(".dropdown-menu>li")[0] //All focused?
            );
            //first college in selected campus
            var firstChild = curFocused.find(".college-list").first()[0];
            //next college
            var nextCollege = curFocused.next(".college-list")[0];
            //next campus
            var nextCampus = 
                curFocused.parents(".dropdown-header").next(".divider").next(".dropdown-header")[0] ||
                curFocused.next(".divider").next(".dropdown-header")[0];
            var toBeFocused = $(firstChild || nextCollege || nextCampus); 
            toBeFocused.focus();
        } else if (e.which == 38 || e.which == 37) { //up or left arrow key {
            var allFocused = $("*").has(":focus").addBack(":focus");
            var curFocused = $(
                allFocused.filter(".college-list")[0] || //college focused?
                allFocused.filter(".dropdown-header")[0] || //campus focused?
                allFocused.filter(".dropdown-menu>li")[0] //All focused?
            );
            //last college in selected campus
            var lastChild = curFocused.find(".college-list").last()[0];
            //prev college
            var prevCollege = curFocused.prev(".college-list")[0];
            //prev campus
            var prevCampus = 
                curFocused.parents(".dropdown-header").prev(".divider").prev(".dropdown-header")[0] ||
                curFocused.prev(".divider").prev(".dropdown-header")[0];
            //all colleges option
            var allColleges = $("#college-opt1");
            var toBeFocused = $(lastChild || prevCollege || prevCampus || allColleges);
            toBeFocused.focus();
        } else if (e.which == 32 || e.which == 13) { //select with space/enter
           $(":focus").trigger("click");
        } 

    });

    //Keyboard navigation for search input field
    $("#search").keydown(function(e) {
        //suggestions will be checkboxes on the major page but lis on courses
        var inputs = $("#suggestions .suggested_major input");
        //if the input exists, use it, otherwise use the li
        var suggestedMajor = inputs.length ? inputs : $("#suggestions .suggested_major");
        if (e.which == 40 || e.which == 39) { //down arrow key - go to first suggestion
            suggestedMajor.first().focus();
        } else if (e.which == 38) //up arrow key - go to last suggestion
            suggestedMajor.last().focus();
        else if (e.which == 13) { //enter key - search for keyword in input field
            goSearch();
        }
    });

    initKeyboardNav();
}


//Create the areas of the search suggestions box - one area for the currently selected college (if any) and one for each campus
function prepareResults(e) {
    //close college dropdown menu if it is currently open
    if ($("#college-dropdown .dropdown-menu").css("display") != "none") {
        $("#dropdownMenu").dropdown("toggle");
    }
    if (window.location.pathname == "/major-gpa/") {
        var source = $("#major-prepare-results").html();
    } else {
        var source = $("#prepare-results").html();
    }
    var template = Handlebars.compile(source);
    $("#suggestions").html(template({
        selected_campus: $("#dropdownMenu").val().toUpperCase(),
        current_campus: _currentCampus.toUpperCase()
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

    if ($("#dropdownMenu").val() == "All") {
        $("#selectedCollege").remove();
        if ($("#selectedCollegeHeader")[0]) {
            $("#selectedCollegeHeader").remove();
        }
    } else {
        if (all_data_loaded && $("#selectedCollege .suggested_major").length < 1 && $("#dropdownMenu").val() != "All") {
            $("#selectedCollege").append(template({
                message: "No matching major in this college"
            }));
        } else if ($("#selectedCollege .suggested_major").length < 1 && $("#dropdownMenu").val() != "All") {
            $("#selectedCollege").append(template({
                message: "Loading..."
            }));
        }
        $("#selectedCollege").append(template_divider({}));
    }

    // Handle current campus
    if ($("#currentCampus .suggested_major").length == 0) {
        $("#currentCampus").remove();
        if ($("#currentCampusHeader")[0]) {
            $("#currentCampusHeader").remove();
        } 
    } else {
        $("#currentCampus").append(template_divider({}));
    }

    // Handle bothell campus
    if ($("#bothellCampus .suggested_major").length == 0) {
        $("#bothellCampus").remove();
        if ($("#bothellCampusHeader")[0]) {
            $("#bothellCampusHeader").remove();
        } 
    } else {
        $("#bothellCampus").append(template_divider({}));
    }

    // Handle seattle campus
    if ($("#seattleCampus .suggested_major").length == 0) {
        $("#seattleCampus").remove();
        if ($("#seattleCampusHeader")[0]) {
            $("#seattleCampusHeader").remove();
        } 
    } else {
        $("#seattleCampus").append(template_divider({}));
    }

    // Handle tacoma campus
    if ($("#tacomaCampus .suggested_major").length == 0) {
        $("#tacomaCampus").remove();
        if ($("#tacomaCampusHeader")[0]) {
            $("#tacomaCampusHeader").remove();
        } 
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
    $("#college-dropdown .dropdown-menu li.college-list").click(function(){
        // Remove the previously selected dropdown option
        var prev_selected = $("#college-dropdown .dropdown-menu .active");
        prev_selected.removeClass("active");
        prev_selected.removeAttr("aria-selected");

        // Visually select the clicked on option
        $(this).addClass("active");
        $(this).attr("aria-selected","true");

        var selection_source = $("#populate-college-dropdown-college-selection").html();
        var selection_template = Handlebars.compile(selection_source);

        $("#dropdownMenu").html(selection_template({college_selection: $(this).text()}));
        if ($(this).text() === "All Colleges") {
            $("#dropdownMenu").val("All");
        } else {
            $("#dropdownMenu").val($(this).text());
        }
        var campus = $(this.classList).filter(["Seattle", "Bothell", "Tacoma"])[0];
        $("#dropdownMenu").attr("data-campus", campus);
        toggleGo();
        setTimeout(prepareResults, 10);
        $( "#dropdownMenu" ).focus();
    });

    //If this is the course page and a code is provided, load the data without searching
    if (window.location.pathname == '/course-gpa/' && getParameterByName("code") != null) {
        var major = getParameterByName("code").replace("_", " ").trim();

        if (_statusLookup.hasOwnProperty(major)) {
            storeSelections(major);
        } else {
            storeSelections(null);
            $(".invalid-major-code-warning").css("display", "inline");
            var source = $("#invalid-major-code-warning").html();
            var template = Handlebars.compile(source);
            $(".invalid-major-code-warning").html(template({codes: major, plural: false}))
        }

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

// Set url parameters
function setUrlParameter(url, key, value) {
    var key = encodeURIComponent(key),
        value = encodeURIComponent(value);

    var baseUrl = url.split('?')[0],
        newParam = key + '=' + value,
        params = '?' + newParam;

    if (url.split('?')[1] === undefined){ // if there are no query strings, make urlQueryString empty
        urlQueryString = '';
    } else {
        urlQueryString = '?' + url.split('?')[1];
    }

    // If the "search" string exists, then build params from it
    if (urlQueryString) {
        var updateRegex = new RegExp('([\?&])' + key + '=[^&]*');
        var removeRegex = new RegExp('([\?&])' + key + '=[^&;]+[&;]?');

        if (value === undefined || value === null || value === '') { // Remove param if value is empty
            params = urlQueryString.replace(removeRegex, "$1");
            params = params.replace(/[&;]$/, "");
    
        } else if (urlQueryString.match(updateRegex) !== null) { // If param exists already, update it
            params = urlQueryString.replace(updateRegex, "$1" + newParam);
    
        } else if (urlQueryString == '') { // If there are no query strings
            params = '?' + newParam;
        } else { // Otherwise, add it to end of query string
            params = urlQueryString + '&' + newParam;
        }
    }

    // no parameter was set so we don't need the question mark
    params = params === '?' ? '' : params;

    return baseUrl + params;
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
    // Edge case in which the user has selected options but hasn't typed anything
    // instead of saying "X results for ''", it will simply say "X results"
    if (raw_search === "") {
        suggestion_text = suggestion_text.substring(0, suggestion_text.length - 6);
    }
    document.getElementById("numResults").innerHTML = suggestion_text;
}

var typingTimer;
var doneTypingInterval = 500; // time in milliseconds

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
