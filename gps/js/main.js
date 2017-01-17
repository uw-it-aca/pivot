//Functions shared by major and course pages

//Data storage
var _majorLookup = {};
var _completeMajorMap = [];
var _currentCampus = "Seattle";
var _timer;//Timer to hide search suggestions after period of inactivity - used in major.js

var _campusNameLookup = {};
var _majorNameLookup = {};
var _courseNameLookup = {};
var update_results_on_load = false;
var all_data_loaded = false;
var _searchResultsChecked = false;

/**** SETUP ****/
if (window.location.search == "?slow") {
    window.setTimeout(function() { getDataNameMap(); }, 5000);
}
else {
    getDataNameMap();
}

//initializes Bootstrap popover plugin
$(function () {
    $('[data-toggle="popover"]').popover()
})

/**** READ DATA FROM CSV ****/

//Reads file that maps data from course file to major file
function getDataNameMap() {
    d3.csv("Assets/v7 - Data Map.csv", function(d) {
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
    d3.csv("Assets/v7 - Majors and Courses.csv", function(d) {
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
        addStudents();
    });
}

//Reads student data file
function addStudents() {
    d3.csv("Assets/v7 - Student Data - All Majors.csv", function (d) {
        return {
            major_abbr: d.major_abbr.trim(),
            pathway: d.pathway.trim(),
            college: d.College.trim(),
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

        if (update_results_on_load) {
            prepareResults();

        }
    });

}

/***SEARCH***/

//When user clicks or tabs in to search field...
$("#search").on("focus", function() {
    _searchResultsChecked = false;
    prepareResults();
});

//When user types in search field...
$("#search").on("input", prepareResults); 

//When user clicks on college dropdown menu, hide search suggestions
$("#dropdownMenu").on("click", function(e) {
    $("#suggestions").css("display","none");
});

//Keyboard navigation for search input field
$("#search").keydown(function(e) {
    if (e.which == 40) { //down arrow key - go to first suggestion
       $("#suggestions a").first().focus();
   } else if (e.which == 38) //up arrow key - go to last suggestion
      $("#suggestions a").last().focus();
    else if (e.which == 13) { //enter key - search for keyword in input field
        goSearch();
    }
});

//Keyboard navigation for search suggestions/results box
$("#suggestions").keydown(function(e) {
   clearTimeout(_timer); //cancel timer checking for inactivity
    if (e.which == 40) { //down arrow key
       e.preventDefault();
       if (!$("a:focus").parent("li").next().is(".divider")) {
           if (!$("a:focus").is("#suggestions ul:last-child li:last-child a:last-child"))
               $("a:focus").parent("li").next().children("a:first-child").focus();   
           else ($("#suggestions a").first().focus());
       }
       else $("a:focus").parent("li").parent("ul").next().children("li").children("a").first().focus();
   } else if (e.which == 38) { //up arrow key
       e.preventDefault();
       if (!$("a:focus").parent("li").prev().is(".dropdown-header"))
           $("a:focus").parent("li").prev().children("a:first-child").focus();
       else {
           if (!$("a:focus").is("#suggestions ul:first-child a:first-child"))
               $("a:focus").parent("li").parent("ul").prev().children("li").children("a").last().focus();
           else ($("#suggestions a").last().focus());
       }
   }
});

//Create the areas of the search suggestions box - one area for the currently selected college (if any) and one for each campus
function prepareResults(e) {
    //close college dropdown menu if it is currently open
    if ($(".dropdown-menu").css("display") != "none")
        $("#dropdownMenu").dropdown("toggle");
    $("#suggestions").html('<ul id="selectedCollege"><li class="dropdown-header">' + $("#dropdownMenu:first-child").val() + '</li></ul><ul id="currentCampus"><li class="dropdown-header">' + _currentCampus + ' campus</li></ul><ul id="bothellCampus"><li class="dropdown-header">Bothell campus</li></ul><ul id="seattleCampus"><li class="dropdown-header">Seattle campus</li></ul><ul id="tacomaCampus"><li class="dropdown-header">Tacoma campus</li></ul>');
    //If a college is selected from the dropdown menu or text has been entered in the input field
    if ($("#dropdownMenu:first-child").val() != "All" || $("#search").val().length > 0) {
        displayResults();
    } else if ($(".chosen_major").length > 0) { //If nothing has been entered in the text field, but the user has made selections
        showCurrentSelections();
    } else { //Nothing to display
        $("#suggestions").css("display","none");
    }
    toggleGo(); //Update the "go" button display
    finishResults(); //Display search suggestions
    updateEvents();
}

//Hides unused placeholder areas in search suggestions
function finishResults() {
    if ($("#dropdownMenu:first-child").val() == "All")
        $("#selectedCollege").remove();
    else {
        if (all_data_loaded) {
            if ($("#selectedCollege li").length == 1 && $("#dropdownMenu:first-child").val() != "All")  $("#selectedCollege").append("<li class='noSelect'>No matching major in this college</li>");
            $("#selectedCollege").append('<li role="separator" class="divider"></li>');
        }
        else {
            if ($("#selectedCollege li").length == 1 && $("#dropdownMenu:first-child").val() != "All")  $("#selectedCollege").append("<li class='noSelect'>Loading...</li>");
            $("#selectedCollege").append('<li role="separator" class="divider"></li>');
        }
    }
    if ($("#currentCampus li").length == 1)
        $("#currentCampus").remove();
    else $("#currentCampus").append('<li role="separator" class="divider"></li>');
    if ($("#bothellCampus li").length == 1)
        $("#bothellCampus").remove();
    else $("#bothellCampus").append('<li role="separator" class="divider"></li>');
    if ($("#seattleCampus li").length == 1)
        $("#seattleCampus").remove();
    else $("#seattleCampus").append('<li role="separator" class="divider"></li>');
    if ($("#tacomaCampus li").length == 1)
        $("#tacomaCampus").remove();
    else $("#tacomaCampus").append('<li role="separator" class="divider"></li>');
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
    if (campuses.indexOf("Bothell") == -1)
        campuses.push("Bothell");
    if (campuses.indexOf("Seattle") == -1)
        campuses.push("seattle");
    if (campuses.indexOf("Tacoma") == -1)
        campuses.push("Tacoma");
    $("#college-dropdown .dropdown-menu").append('<li><a href="#">All</a></li><li role="separator" class="divider"></li>');
    $("#dropdownMenu:first-child").val("All");
    for (var c = 0; c < campuses.length; c++) {
        if (c > 0)
            $("#college-dropdown .dropdown-menu").append('<li role="separator" class="divider"></li>');
        $("#college-dropdown .dropdown-menu").append('<li class="dropdown-header college-list">Colleges in ' + campuses[c] + ' campus:</li>');
        var colleges = [];
        for (var maj in _completeMajorMap) {
            if (_completeMajorMap[maj]["campus"] == campuses[c] && colleges.indexOf(_completeMajorMap[maj]["college"]) == -1)
                colleges.push(_completeMajorMap[maj]["college"])
        }
        colleges.sort();
        for (var col in colleges) {
            $("#college-dropdown .dropdown-menu").append('<li><a href="#">' + colleges[col] + '</a></li>');
        }

    }

    //Show selection in button
    $("#college-dropdown .dropdown-menu li a").click(function(){
        $("#dropdownMenu:first-child").html('<span id="college-selection">' + $(this).text()  + ' </span><span class="caret"></span>');
        $("#dropdownMenu:first-child").val($(this).text());
        toggleGo();
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
