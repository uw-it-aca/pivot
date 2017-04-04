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
        path = settings.CSV_ROOT + self.file_name
        with open(path, 'r') as csvfile:
            data = csvfile.read()
            return data


class MajorCourse(DataFileView):
    file_name = "v7 - Majors and Courses.csv"


class DataMap(DataFileView):
    file_name = "v7 - Data Map.csv"


class StudentData(DataFileView):
    file_name = "v7 - Student Data - All Majors.csv"


class StatusLookup(DataFileView):
    file_name = "status-lookup-2017-04.csv"
