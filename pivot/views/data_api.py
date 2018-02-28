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

# In order to get the right import, we need to determine
# the runtime version of python
import sys
if sys.version_info[0] < 3:
    from urlparse import parse_qs
else:
    from urllib.parse import parse_qs


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

        return data


class MajorCourse(DataFileView):
    file_name = "Majors_and_Courses.csv"


class DataMap(DataFileView):
    file_name = "Data_Map.csv"


class StudentData(DataFileView):
    # Default file when there are no queries (aggregate of all years)
    file_name = "Student_Data_All_Majors_All_Years.csv"

    def get(self, request):
        q = parse_qs(request.GET.urlencode())
        if q and q['year']:
            # Year query exists, change the csv file we access
            self.file_name = "Student_Data_All_Majors_%s.csv" % (q['year'][0])
        csv = self._get_csv()
        return HttpResponse(csv)


class StatusLookup(DataFileView):
    file_name = "Status_Lookup.csv"
