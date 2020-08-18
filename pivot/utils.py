import csv
import glob
import os
import re
from io import StringIO
from urllib.error import URLError
from urllib.parse import urljoin
from urllib.request import urlopen
from django.conf import settings
from django.core.files.storage import default_storage


def get_file_data(filename):
    f = default_storage.open(filename, "r")
    data = f.read()
    f.close()
    return data


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
