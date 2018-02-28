import os
try:
    from urllib.parse import urljoin
    from urllib.request import urlopen
except:
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
        if hasattr(settings, 'CSV_URL') and settings.CSV_URL is not None and settings.CSV_URL != '':
            url = urljoin(getattr(settings, 'CSV_URL', None), self.file_name)
        elif hasattr(settings, 'CSV_ROOT') and settings.CSV_ROOT is not None and settings.CSV_ROOT != '':
            url = urljoin('file://', getattr(settings, 'CSV_ROOT', None))
            url = urljoin(url, self.file_name)
        with urlopen(url) as response:
            data = response.read()
        return data


class MajorCourse(DataFileView):
    file_name = "Majors_and_Courses.csv"


class DataMap(DataFileView):
    file_name = "Data_Map.csv"


class StudentData(DataFileView):
    file_name = "Student_Data_All_Majors.csv"


class StatusLookup(DataFileView):
    file_name = "Status_Lookup.csv"
