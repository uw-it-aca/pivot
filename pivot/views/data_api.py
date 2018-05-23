import os
import csv
try:
    from urllib.parse import urljoin
    from urllib.request import urlopen
except ImportError:
    # for Python 2.7 compatibility
    from urlparse import urljoin
    from urllib2 import urlopen

from django.shortcuts import render
from django.views import View
from django.http import HttpResponse
from django.conf import settings


class DataFileView(View):
    file_name = None

    def get(self, request):
        csv = self._get_csv()
        return HttpResponse(csv)

    def _get_csv(self):
        try:
            url = urljoin(getattr(settings, 'CSV_ROOT', None), self.file_name)
            response = urlopen(url)
            data = response.read()
        except ValueError:
            url = urljoin('file://', getattr(settings, 'CSV_ROOT', None))
            url = urljoin(url, self.file_name)
            response = urlopen(url)
            data = response.read()
        except Exception as err:
            data = "Error {}: {}".format(err.errno, err.reason)

        csv_data = [line.split(b",") for line in data.splitlines()]
        header = csv_data[0]
        csv_data = csv_data[1:]
        # Columns we have to scrub out an & (note double quotes are included)
        # because thats how it is formatted in the csv files...
        scrub = [b'"major_path"', b'"course_num"', b'"code"']
        check_index = []
        for s in scrub:
            if s in header:
                check_index.append(header.index(s))

        if len(check_index) == 0:
            return data
        else:
            for line in csv_data:
                for index in check_index:
                    line[index] = line[index].replace(b"&", b"_AND_")

            csv_data = [header] + csv_data
            scrubbed_data = b"\n".join([b",".join(c) for c in csv_data])
            return scrubbed_data


class MajorCourse(DataFileView):
    file_name = "Majors_and_Courses.csv"


class DataMap(DataFileView):
    file_name = "Data_Map.csv"


class StudentData(DataFileView):
    file_name = "Student_Data_All_Majors.csv"


class StatusLookup(DataFileView):
    file_name = "Status_Lookup.csv"
