import os
try:
    from urllib.parse import urljoin, parse_qs
    from urllib.request import urlopen
except ImportError:
    # for Python 2.7 compatibility
    from urlparse import urljoin, parse_qs
    from urllib2 import urlopen

from django.shortcuts import render
from django.views import View
from django.http import HttpResponse
from django.conf import settings
from django.http import Http404


class DataFileView(View):
    file_name = None

    def get(self, request):
        try:
            csv = self._get_csv()
        except Exception as err:
            raise Http404(err.message)
        return HttpResponse(csv)

    def _get_csv(self):
        try:
            url = urljoin(getattr(settings, 'CSV_ROOT', None), self.file_name)
            response = urlopen(url)
            data = response.read()
        except ValueError:
            # If a ValueError, CSV_ROOT was not set to file format (file://)
            try:
                # Try using the alternative format...
                url = urljoin('file://', getattr(settings, 'CSV_ROOT', None))
                url = urljoin(url, self.file_name)
                response = urlopen(url)
                data = response.read()
            except Exception as err:
                err.message = "Error {}: {}".format(err.errno, err.reason)
                raise
        except Exception as err:
                err.message = "Error {}: {}".format(err.errno, err.reason)
                raise

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
        try:
            csv = self._get_csv()
        except Exception as err:
            raise Http404(err.message)
        return HttpResponse(csv)


class StatusLookup(DataFileView):
    file_name = "Status_Lookup.csv"
