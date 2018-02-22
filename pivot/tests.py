import os

from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase
from django.test.utils import override_settings

import pivot


TEST_CSV_ROOT = os.path.join(os.path.dirname(pivot.__file__),
                             'test_resources',
                             'csvfiles/',)


class CsvDataApiTest(TestCase):
    """ Tests the api/v1 CSV apis.
    """
    def setUp(self):
        self.user = User.objects.create(username='testuser')
        self.user.set_password('password')
        self.user.save()

    def tearDown(self):
        self.user.delete()

    @override_settings(CSV_ROOT=TEST_CSV_ROOT)
    def test_major_course(self):
        self._major_course()

    @override_settings(CSV_ROOT=TEST_CSV_ROOT)
    def test_data_map(self):
        self._data_map()

    @override_settings(CSV_ROOT=TEST_CSV_ROOT)
    def test_status_lookup(self):
        self._status_lookup()

    @override_settings(CSV_ROOT=TEST_CSV_ROOT)
    def test_student_data(self):
        self._student_data()

    # TODO: Now override with CSV_URL, instead

    def _major_course(self):
        url = '/api/v1/major_course/'
        file_name = 'Majors_and_Courses.csv'
        path = os.path.join(settings.CSV_ROOT, file_name)
        with open(path, 'r') as csvfile:
            data = csvfile.read()
            data = data.encode()  # For comparison to bytes type

        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertTrue(data == response.content)

    def _data_map(self):
        url = '/api/v1/data_map/'
        file_name = 'Data_Map.csv'
        path = os.path.join(settings.CSV_ROOT, file_name)
        with open(path, 'r') as csvfile:
            data = csvfile.read()
            data = data.encode()  # For comparison to bytes type

        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertTrue(data == response.content)

    def _status_lookup(self):
        url = '/api/v1/status_lookup/'
        file_name = 'Status_Lookup.csv'
        path = os.path.join(settings.CSV_ROOT, file_name)
        with open(path, 'r') as csvfile:
            data = csvfile.read()
            data = data.encode()  # For comparison to bytes type

        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertTrue(data == response.content)

    def _student_data(self):
        url = '/api/v1/student_data/'
        file_name = 'Student_Data_All_Majors.csv'
        path = os.path.join(settings.CSV_ROOT, file_name)
        with open(path, 'r') as csvfile:
            data = csvfile.read()
            data = data.encode()  # For comparison to bytes type

        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertTrue(data == response.content)
