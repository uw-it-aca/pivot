import csv
import glob
import os
from io import StringIO
from urllib.error import URLError
from urllib.parse import urljoin
from urllib.request import urlopen

from django.conf import settings


def get_latest_term():
    student_data_term_set =\
        get_quarters_for_file("student_data_all_majors.csv")
    major_course_term_set = get_quarters_for_file("majors_and_courses.csv")
    term_set = student_data_term_set.intersection(major_course_term_set)
    newest_term = next(iter(term_set))

    for term in term_set:
        if is_more_recent(term, newest_term):
            newest_term = term

    return newest_term


def get_quarters_for_file(filename):
    data_dir = getattr(settings, 'CSV_ROOT', None)
    if data_dir[0:7] == "file://":
        data_dir = data_dir[7:]
    full_paths = glob.glob(data_dir + "*_*qtrs_" + filename)
    file_names = list(map(lambda s: s.split('/')[-1], full_paths))
    terms = set(map(lambda s: s.split('_')[0], file_names))
    return terms


def is_more_recent(new_term, old_term):
    try:
        old_year = int(old_term[2:])
        new_year = int(new_term[2:])
    except ValueError:
        print("Filename is not properly formatted")

    if (new_year > old_year):
        return True

    if (new_year < old_year):
        return False

    QUARTERS = ["wi", "sp", "su", "au"]

    try:
        new_qtr = QUARTERS.index(new_term[:-2])
        old_qtr = QUARTERS.index(old_term[:-2])
    except ValueError:
        print("Filename is not properly formatted")

    return new_qtr > old_qtr
