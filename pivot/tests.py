import os

from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase
from django.test.utils import override_settings

import pivot


@override_settings(CSV_ROOT=os.path.join(os.path.dirname(pivot.__file__),
                                         'test_resources',
                                         'csvfiles',))
class CsvDataApiTest(TestCase):
    """ Tests the api/v1 CSV apis.
    """
    def setUp(self):
        self.user = User.objects.create_user(username='testuser',
                                             password='password')

    def tearDown(self):
        self.user.delete()

    def test_major_course(self):
        url = '/api/v1/major_course/'
        file_name = 'Majors_and_Courses.csv'
        path = os.path.join(settings.CSV_ROOT, file_name)
        with open(path, 'r') as csvfile:
            data = csvfile.read()

        login_successful = self.client.login(username='testuser',
                                             password='password')
        print(login_successful)
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertTrue(data == response.content)

    def test_data_map(self):
        url = '/api/v1/data_map/'
        file_name = 'Data_Map.csv'
        path = os.path.join(settings.CSV_ROOT, file_name)
        with open(path, 'r') as csvfile:
            data = csvfile.read()

        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertTrue(data == response.content)

    def test_status_lookup(self):
        url = '/api/v1/status_lookup/'
        file_name = 'Status_Lookup.csv'
        path = os.path.join(settings.CSV_ROOT, file_name)
        with open(path, 'r') as csvfile:
            data = csvfile.read()

        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertTrue(data == response.content)

    def test_student_data(self):
        url = '/api/v1/student_data/'
        file_name = 'Student_Data_All_Majors.csv'
        path = os.path.join(settings.CSV_ROOT, file_name)
        with open(path, 'r') as csvfile:
            data = csvfile.read()

        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertTrue(data == response.content)
