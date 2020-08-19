import re
import csv
from io import StringIO
from django.conf import settings
from django.core.files.storage import default_storage


def get_file_data(filename):
    out = StringIO()
    writer = csv.writer(out)
    with default_storage.open(filename, mode="r") as csvfile:
        # csv.reader has to take in string not bytes
        try:
            reader = csv.reader(csvfile.read().decode("utf-8"))
        except AttributeError:
            reader = csv.reader(csvfile)

        header = [s.lower() for s in next(reader)]
        writer.writerow(header)

        # Columns we have to scrub out an & (note double quotes are included)
        # because thats how it is formatted in the csv files
        check_index = []
        for s in ["major_path", "code", "key"]:
            if s in header:
                check_index.append(header.index(s))

        for row in reader:
            if len(check_index):
                for index in check_index:
                    row[index] = row[index].replace(" ", "-")
                    row[index] = row[index].replace("&", "_AND_")
                    row[index] = row[index].replace(":", "_")
            writer.writerow(row)

    return out.getvalue().strip("\r\n")


def get_latest_term():
    student_data_term_set = get_quarters_for_file(
        "student_data_all_majors.csv"
    )
    major_course_term_set = get_quarters_for_file("majors_and_courses.csv")
    term_set = student_data_term_set.intersection(major_course_term_set)
    newest_term = next(iter(term_set))

    for term in term_set:
        if is_more_recent(term, newest_term):
            newest_term = term

    return newest_term


def get_quarters_for_file(filename):
    terms = set()
    data_dir = getattr(settings, "MEDIA_ROOT", None)
    for item in default_storage.listdir(data_dir):
        for fname in item:
            match = re.match(r'^(.+?)_.*{0}$'.format(filename), fname)
            if match:
                terms.add(match.group(1))
    return terms


def is_more_recent(new_term, old_term):
    try:
        old_year = int(old_term[2:])
        new_year = int(new_term[2:])
    except ValueError:
        print("Filename is not properly formatted")

    if new_year > old_year:
        return True

    if new_year < old_year:
        return False

    QUARTERS = ["wi", "sp", "su", "au"]

    try:
        new_qtr = QUARTERS.index(new_term[:-2])
        old_qtr = QUARTERS.index(old_term[:-2])
    except ValueError:
        print("Filename is not properly formatted")

    return new_qtr > old_qtr
