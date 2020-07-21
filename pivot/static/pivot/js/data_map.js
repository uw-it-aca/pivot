const DataMap = {
    process_data () {
        const data = WSData.data_map_data();
        const parsed_csv = d3.csv.parse(data);

        d3.csv.parse(data, (d) => {
            return {
                is_course: d.is_course.trim(),
                is_major: d.is_major.trim(),
                is_campus: d.is_campus.trim(),
                name: d.name.trim(),
                id: d.id.trim(),
            };
        }, (error, data) => {
            for (const index in data) {
                if (parseInt(data[index].is_course)) {
                    _courseNameLookup[data[index].id] = data[index].name
                }

                if (parseInt(data[index].is_major)) {
                    _majorNameLookup[data[index].id] = data[index].name
                }

                if (parseInt(data[index].is_campus)) {
                    _campusNameLookup[data[index].id] = data[index].name
                }
            }
        });
    },
}
