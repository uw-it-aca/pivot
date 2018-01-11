# This converts raw student data into one line per major, with the
# quartiles and iqr ranges defined.

# Given the location of the original Student Data - All Majors csv file
# spits out...
# Student_Data_All_Majors.csv: modified version of the original

import sys
import csv

data = {}

if (len(sys.argv) < 2):
    sys.exit('Please pass in the major file to parse as an argument!')

with open(sys.argv[1]) as f:
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

        if key not in data:
            data[key] = {"raw": row, "gpas": []}

        data[key]["gpas"].append(float(gpa))

with open('Student_Data_All_Majors.csv', 'wb') as outf:
    csv_out = csv.writer(outf, delimiter=',')
    csv_out.writerow(["major_abbr", "pathway", "College", "iqr_min",
                      "q1", "median", "q3", "iqr_max"])

    for key in data:
        gpas = sorted(data[key]["gpas"])
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

        print "IQR Min, Max: ", gpas[iqr_index_min], gpas[iqr_index_max]
        csv_out.writerow([data[key]["raw"][2],
                          data[key]["raw"][3],
                          data[key]["raw"][5],
                          gpas[iqr_index_min],
                          qv1,
                          median,
                          qv3,
                          gpas[iqr_index_max]])
