# Copyright 2022 UW-IT, University of Washington
# SPDX-License-Identifier: Apache-2.0

from logging import getLogger
from urllib.error import URLError
from django.conf import settings
from django.http import HttpResponse, HttpResponseBadRequest
from django.shortcuts import render
from django.utils.decorators import method_decorator
from django.views import View

from pivot.utils import get_latest_term, get_file_data

from uw_saml.decorators import group_required

logger = getLogger(__name__)
PIVOT_ACCESS_GROUP = settings.PIVOT_AUTHZ_GROUPS["access"]


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name="dispatch")
class DataFileView(View):
    file_name = None

    def get(self, request):
        try:
            return HttpResponse(get_file_data(self.file_name))
        except FileNotFoundError as err:
            logger.warning(
                "Error {}: {} not found.".format(err.errno, err.filename))
            return HttpResponse("Data not available", status=416)


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name="dispatch")
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
            return HttpResponseBadRequest(
                "Quarter must be one of 'au', 'wi', 'sp', or 'su'"
            )

        num_qtrs = request.GET.get("num_qtrs", "8")

        try:
            int(num_qtrs)
        except ValueError:
            return HttpResponseBadRequest(
                "Number of quarters must be an integer"
            )

        if int(num_qtrs) < 1:
            return HttpResponseBadRequest(
                "Number of quarters must be at least 1"
            )

        self.file_name = (
            end_quarter
            + str(end_year)
            + "_"
            + num_qtrs
            + "qtrs_"
            + self.base_file_name
        )

        try:
            return super(DataFileByQuarterView, self).get(request)
        except URLError:
            return HttpResponse(
                "There is no data for the requested time period",
                status=416,
            )


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name="dispatch")
class MajorCourse(DataFileByQuarterView):
    base_file_name = "majors_and_courses.csv"


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name="dispatch")
class DataMap(DataFileView):
    file_name = "data_map.csv"


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name="dispatch")
class StudentData(DataFileByQuarterView):
    base_file_name = "student_data_all_majors.csv"


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name="dispatch")
class StatusLookup(DataFileView):
    file_name = "status_lookup.csv"
