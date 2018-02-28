import os
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
            data = "Error: {}".format(err)

        return data


class MajorCourse(DataFileView):
    file_name = "Majors_and_Courses.csv"


class DataMap(DataFileView):
    file_name = "Data_Map.csv"


class StudentData(DataFileView):
    file_name = "Student_Data_All_Majors.csv"


class StatusLookup(DataFileView):
    file_name = "Status_Lookup.csv"
