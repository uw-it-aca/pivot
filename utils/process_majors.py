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


def sort_by_course_and_popularity(a, b):
    return -1

if (len(sys.argv) < 2):
    sys.exit('Please pass in the major file to parse as an argument!')

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
        csv_out.writerow([
            original_row[0],
            original_row[1],
            original_row[2],
            original_row[3],
            original_row[4],
            original_row[5],
            data[key]['50'],
            course_name_map[original_row[8]],
            major_name_map[original_row[9]],
            original_row[10],
            original_row[11],
            campus_name_map[original_row[12]],
        ])
