# This converts raw Majors and Courses data into the more compact version
# with one line per major, and the percentiles broken out.

# Given the location of the original Majors and Courses csv file
# spits out...
# Majors_and_Courses.csv: modified version of the original
# Data_Map.csv: file that contains the abbreviated names

import sys
import csv

data = {}
course_name_map = {}
major_name_map = {}
campus_name_map = {}

# Exceptions to make.
# Example: "NURSX": "Nursing (Accelerated)" means that we should replace the
# major name of NURSX with Nursing (Accelerated) instead of the csv value
major_name_exc = {
    "NURSX": "Nursing (Accelerated)"
}
# Ignore majors with less than st_num students
st_num = 5
# Majors who disqualify (< 5 students)
little_majors = set([])


def sort_by_course_and_popularity(a, b):
    return -1

if (len(sys.argv) < 3):
    sys.exit('Please pass in the Majors and Courses file AND ' +
             'the Student Data - All Majors file to parse as arguments!')

with open(sys.argv[1]) as f:
    as_csv = csv.reader(f)
    header = as_csv.next()
    for row in as_csv:
        major_abbr = row[0]
        pathway = row[1]
        dept_abbrev = row[2]
        course_number = row[3]
        student_count = row[4]
        students_in_major = row[5]
        percentile = row[6]
        course_gpa = row[7]
        CourseLongName = row[8]
        major_full_nm = row[9]
        MajorID = row[10]
        CoursePopularityRank = int(row[11])
        Campus = row[12]

        if (int(students_in_major) < st_num):
            little_majors.add(major_abbr.strip() + "_" + pathway)
            continue

        # major_abbr stripped
        abbr = major_abbr.strip()
        # Check if the abbr is in the major exceptions dict
        if (abbr in major_name_exc and
                major_name_exc[abbr] not in major_name_map):
            # Put in the appropriate major name
            major_name_map[major_name_exc[abbr]] = len(major_name_map.keys())

        if CourseLongName not in course_name_map:
            course_name_map[CourseLongName] = len(course_name_map.keys())

        if Campus not in campus_name_map:
            campus_name_map[Campus] = len(campus_name_map.keys())

        if major_full_nm not in major_name_map:
            major_name_map[major_full_nm] = len(major_name_map.keys())

        if CoursePopularityRank <= 10:
            pop = CoursePopularityRank
            if pop < 10:
                pop = "0%s" % pop
            combo_key = "%s-%s-%s-%s-%s-%s-%s" % (major_abbr, pathway, pop,
                                                  dept_abbrev, course_number,
                                                  MajorID, Campus)

            if combo_key not in data:
                data[combo_key] = {"base": row}

            data[combo_key][percentile] = course_gpa

with open('Data_Map.csv', 'wb') as outf:
    csv_out = csv.writer(outf, delimiter=',')
    csv_out.writerow(["is_course", "is_major", "is_campus", "name", "id"])

    for key in sorted(course_name_map.keys()):
        csv_out.writerow([1, 0, 0, key, course_name_map[key]])

    for key in sorted(major_name_map.keys()):
        csv_out.writerow([0, 1, 0, key, major_name_map[key]])

    for key in sorted(campus_name_map.keys()):
        csv_out.writerow([0, 0, 1, key, campus_name_map[key]])


with open('Majors_and_Courses.csv', 'wb') as outf:
    csv_out = csv.writer(outf, delimiter=',')
    csv_out.writerow(["major_abbr", "pathway", "dept_abbrev",
                      "course_number", "student_count",
                      "students_in_major", "course_gpa_50pct",
                      "CourseLongName", "major_full_nm", "MajorID",
                      "CoursePopularityRank", "Campus"])

    for key in sorted(data.keys()):
        original_row = data[key]["base"]

        major_name_id = major_name_map[original_row[9]]
        abbr = original_row[0].strip()
        # Check to see there is an exception to the major id we need to include
        if (abbr in major_name_exc):
            major_name_id = major_name_map[major_name_exc[abbr]]

        csv_out.writerow([
            original_row[0],
            original_row[1],
            original_row[2],
            original_row[3],
            original_row[4],
            original_row[5],
            data[key]['50'],
            course_name_map[original_row[8]],
            major_name_id,
            original_row[10],
            original_row[11],
            campus_name_map[original_row[12]],
        ])

# --------------------------------------------------------------------
# This converts raw student data into one line per major, with the
# quartiles and iqr ranges defined.

# Given the location of the original Student Data - All Majors csv file
# spits out...
# Student_Data_All_Majors.csv: modified version of the original

sdata = {}

with open(sys.argv[2]) as f:
    as_csv = csv.reader(f)
    header = as_csv.next()
    for row in as_csv:
        major_id = row[0]
        fake_id = row[1]
        major_abbr = row[2]
        pathway = row[3]
        campus = row[4]
        college = row[5]
        major_name = row[6]
        gpa = row[7]

        key = "%s - %s" % (major_abbr, pathway)

        if major_abbr.strip() + "_" + pathway in little_majors:
            # This major had less than st_num students, ignore
            continue

        if key not in sdata:
            sdata[key] = {"raw": row, "gpas": []}

        sdata[key]["gpas"].append(float(gpa))

with open('Student_Data_All_Majors.csv', 'wb') as outf:
    csv_out = csv.writer(outf, delimiter=',')
    csv_out.writerow(["major_abbr", "pathway", "College", "iqr_min",
                      "q1", "median", "q3", "iqr_max"])

    for key in sdata:
        gpas = sorted(sdata[key]["gpas"])
        q1 = int(len(gpas) * .25)
        q2 = int(len(gpas) * .5)
        q3 = int(len(gpas) * .75)

        qv1 = gpas[q1]
        if len(gpas) % 2:
            median = gpas[q2]
        else:
            median = (gpas[q2] + gpas[q2-1]) / 2
        qv3 = gpas[q3]

        iqr = (qv3-qv1) * 1.5

        iqr_index_min = 0
        iqr_index_max = len(gpas) - 1

        while iqr_index_min < len(gpas) and gpas[iqr_index_min] < qv1 - iqr:
            iqr_index_min += 1

        while iqr_index_max > 0 and gpas[iqr_index_max] > qv3 + iqr:
            iqr_index_max -= 1

        # print "IQR Min, Max: ", gpas[iqr_index_min], gpas[iqr_index_max]
        csv_out.writerow([sdata[key]["raw"][2],
                          sdata[key]["raw"][3],
                          sdata[key]["raw"][5],
                          gpas[iqr_index_min],
                          qv1,
                          median,
                          qv3,
                          gpas[iqr_index_max]])