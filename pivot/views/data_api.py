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
    file_name = "Majors_and_Courses.csv"


class DataMap(DataFileView):
    file_name = "Data_Map.csv"


class StudentData(DataFileView):
    file_name = "Student_Data_All_Majors.csv"


class StatusLookup(DataFileView):
    file_name = "Status_Lookup.csv"
