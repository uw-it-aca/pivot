import os
try:
    from urllib.parse import urljoin
except:
    # for Python 2.7 compatibility
    from urlparse import urljoin

from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase
from django.test.utils import override_settings

import pivot


TEST_CSV_PATH = os.path.join(os.path.dirname(pivot.__file__),
                             'test_resources',
                             'csvfiles/',)
TEST_CSV_URL = urljoin('file://', TEST_CSV_PATH)


class CsvDataApiTest(TestCase):
    """ Tests the api/v1 CSV apis.
    """
    def setUp(self):
        self.user = User.objects.create(username='testuser')
        self.user.set_password('password')
        self.user.save()

    def tearDown(self):
        self.user.delete()

    @override_settings(CSV_ROOT=TEST_CSV_PATH)
    def test_major_course_path(self):
        self._major_course()

    @override_settings(CSV_ROOT=TEST_CSV_URL)
    def test_major_course_url(self):
        self._major_course()

    @override_settings(CSV_ROOT=TEST_CSV_PATH)
    def test_data_map_path(self):
        self._data_map()

    @override_settings(CSV_ROOT=TEST_CSV_URL)
    def test_data_map_url(self):
        self._data_map()

    @override_settings(CSV_ROOT=TEST_CSV_PATH)
    def test_status_lookup_path(self):
        self._status_lookup()

    @override_settings(CSV_ROOT=TEST_CSV_URL)
    def test_status_lookup_url(self):
        self._status_lookup()

    @override_settings(CSV_ROOT=TEST_CSV_PATH)
    def test_student_data_path(self):
        self._student_data()

    @override_settings(CSV_ROOT=TEST_CSV_URL)
    def test_student_data_url(self):
        self._student_data()

    # TODO: Now override with CSV_URL, instead

    def _major_course(self):
        url = '/api/v1/major_course/'
        file_name = 'Majors_and_Courses.csv'
        path = os.path.join(TEST_CSV_PATH, file_name)
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
        path = os.path.join(TEST_CSV_PATH, file_name)
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
        path = os.path.join(TEST_CSV_PATH, file_name)
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
        path = os.path.join(TEST_CSV_PATH, file_name)
        with open(path, 'r') as csvfile:
            data = csvfile.read()
            data = data.encode()  # For comparison to bytes type

        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertTrue(data == response.content)
