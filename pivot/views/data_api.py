import csv
import os
from io import StringIO
from urllib.error import URLError
from urllib.parse import urljoin
from urllib.request import urlopen

from django.conf import settings
from django.http import HttpResponse, HttpResponseBadRequest
from django.shortcuts import render
from django.utils.decorators import method_decorator
from django.views import View

from pivot.utils import get_latest_term

from uw_saml.decorators import group_required

PIVOT_ACCESS_GROUP = settings.PIVOT_AUTHZ_GROUPS['access']


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name='dispatch')
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
        header = [str.lower() for str in next(csv_reader)]
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


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name='dispatch')
class DataFileByQuarterView(DataFileView):
    """ Base class for views that take a time period queries
    """

    base_file_name = None

    def get(self, request):
        end_term = None
        end_year = request.GET.get("end_yr")

        if end_year is None:
            if end_term is None:
                end_term = get_latest_term()
            end_year = end_term[2:]

        if len(str(end_year)) > 2:
            return HttpResponseBadRequest("Year must be in a 2 digit format")

        end_quarter = request.GET.get("end_qtr")

        if end_quarter is None:
            if end_term is None:
                end_term = get_latest_term()
            end_quarter = end_term[:2]

        end_quarter = end_quarter.lower()

        if end_quarter not in ["au", "wi", "sp", "su"]:
            return HttpResponseBadRequest("Quarter must be one of 'au',"
                                          + " 'wi', 'sp', or 'su'")

        num_qtrs = request.GET.get("num_qtrs", "8")

        try:
            int(num_qtrs)
        except ValueError:
            return HttpResponseBadRequest("Number of quarters must be"
                                          + " an integer")

        if int(num_qtrs) < 1:
            return HttpResponseBadRequest("Number of quarters must be"
                                          + " at least 1")

        self.file_name = end_quarter + str(end_year) + "_" + num_qtrs\
            + "qtrs_" + self.base_file_name

        try:
            return super(DataFileByQuarterView, self).get(request)
        except URLError:
            return HttpResponse("There is no data for the"
                                + " requested time period", status=416)


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name='dispatch')
class MajorCourse(DataFileByQuarterView):
    base_file_name = "majors_and_courses.csv"


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name='dispatch')
class DataMap(DataFileView):
    file_name = "data_map.csv"


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name='dispatch')
class StudentData(DataFileByQuarterView):
    base_file_name = "student_data_all_majors.csv"


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name='dispatch')
class StatusLookup(DataFileView):
    file_name = "status_lookup.csv"
