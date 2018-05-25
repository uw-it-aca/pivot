import os
import csv
try:
    from urllib.parse import urljoin
except ImportError:
    # for Python 2.7 compatibility
    from urlparse import urljoin
try:
    from StringIO import StringIO
except ImportError:
    from io import StringIO

from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase
from django.test.utils import override_settings

import pivot

TEST_CSV_PATH = os.path.join(os.path.dirname(pivot.__file__),
                             'test_resources',
                             'csvfiles/',)
TEST_CSV_SCRUB_PATH = os.path.join(os.path.dirname(pivot.__file__),
                                   'test_resources',
                                   'csvfiles/scrub/',)
TEST_CSV_URL = urljoin('file://', TEST_CSV_PATH)

# To be used on scrub tests (make sure &'s are replaced with _AND_)
scrubbed_major = b'PB_AND_J_10'


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

    @override_settings(CSV_ROOT=TEST_CSV_SCRUB_PATH)
    def test_scrub_major_course(self):
        url = '/api/v1/major_course/'
        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)
        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        data = [line.split(b",") for line in response.content.splitlines()]
        for i in range(1, len(data)):
            self.assertEqual(data[i][0], scrubbed_major)

    @override_settings(CSV_ROOT=TEST_CSV_SCRUB_PATH)
    def test_scrub_status_lookup(self):
        url = '/api/v1/status_lookup/'
        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)
        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        data = [line.split(b",") for line in response.content.splitlines()]
        self.assertEqual(data[1][0], scrubbed_major)

    @override_settings(CSV_ROOT=TEST_CSV_SCRUB_PATH)
    def test_scrub_student_data(self):
        url = '/api/v1/student_data/'
        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)
        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        data = [line.split(b",") for line in response.content.splitlines()]
        self.assertEqual(data[1][0], scrubbed_major)

    # Helper method, takes in csv_reader and returns
    # a string (to help with eliminating unnecessary ""'s')
    def csv_to_string(self, csv_reader):
        si = StringIO()
        cw = csv.writer(si)
        for row in csv_reader:
            cw.writerow(row)
        return si.getvalue().strip('\r\n')

    # TODO: Now override with CSV_URL, instead
    def _major_course(self):
        url = '/api/v1/major_course/'
        file_name = 'Majors_and_Courses.csv'
        path = os.path.join(TEST_CSV_PATH, file_name)

        with open(path, 'r') as csvfile:
            csv_reader = csv.reader(csvfile)
            data = self.csv_to_string(csv_reader)
            data.encode()

        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertEqual(data, response.content)

    def _data_map(self):
        url = '/api/v1/data_map/'
        file_name = 'Data_Map.csv'
        path = os.path.join(TEST_CSV_PATH, file_name)
        with open(path, 'r') as csvfile:
            csv_reader = csv.reader(csvfile)
            data = self.csv_to_string(csv_reader)
            data.encode()

        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertEqual(data, response.content)

    def _status_lookup(self):
        url = '/api/v1/status_lookup/'
        file_name = 'Status_Lookup.csv'
        path = os.path.join(TEST_CSV_PATH, file_name)
        with open(path, 'r') as csvfile:
            csv_reader = csv.reader(csvfile)
            data = self.csv_to_string(csv_reader)
            data.encode()

        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertEqual(data, response.content)

    def _student_data(self):
        url = '/api/v1/student_data/'
        file_name = 'Student_Data_All_Majors.csv'
        path = os.path.join(TEST_CSV_PATH, file_name)
        with open(path, 'r') as csvfile:
            csv_reader = csv.reader(csvfile)
            data = self.csv_to_string(csv_reader)
            data.encode()

        login_successful = self.client.login(username='testuser',
                                             password='password')
        self.assertTrue(login_successful)

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertEqual(data, response.content)
