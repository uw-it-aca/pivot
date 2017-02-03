var DataMap = {
    process_data: function () {
        var data = WSData.data_map_data(),
            parsed_csv = d3.csv.parse(data);

        //
        //$(parsed_csv).each(idx, data){
        //
        //}
        d3.csv.parse(data, function(d) {
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
            console.log(_campusNameLookup);
            //getCompleteMajorMap();
        });
    },
}