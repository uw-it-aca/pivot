import os
import csv

try:
    from StringIO import StringIO
except ImportError:
    from io import StringIO

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

        si = StringIO()
        cw = csv.writer(si)
        # csv.reader has to take in string not bytes...
        csv_reader = csv.reader(data.decode("utf-8").splitlines())

        # csv_data = [line.split(b",") for line in data.splitlines()][0]
        header = [str.lower() for str in csv_reader.next()]
        cw.writerow(header)
        # Columns we have to scrub out an & (note double quotes are included)
        # because thats how it is formatted in the csv files...
        scrub = ['major_path', 'code', 'key']
        check_index = []
        for s in scrub:
            if s in header:
                check_index.append(header.index(s))

        if len(check_index) == 0:
            for row in csv_reader:
                cw.writerow(row)
            return si.getvalue().strip('\r\n')
        else:
            for row in csv_reader:
                for index in check_index:
                    row[index] = row[index].replace(" ", "-")
                    row[index] = row[index].replace("&", "_AND_")
                    row[index] = row[index].replace(":", "_")
                cw.writerow(row)
            return si.getvalue().strip('\r\n')


class MajorCourse(DataFileView):
    file_name = "Majors_and_Courses.csv"


class DataMap(DataFileView):
    file_name = "Data_Map.csv"


class StudentData(DataFileView):
    file_name = "Student_Data_All_Majors.csv"


class StatusLookup(DataFileView):
    file_name = "Status_Lookup.csv"
