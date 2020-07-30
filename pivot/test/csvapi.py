import csv
import os
from io import StringIO
from urllib.parse import urljoin

from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase
from django.test.utils import override_settings

import pivot

TEST_CSV_PATH = os.path.join(os.path.dirname(pivot.__file__),
                             'test',
                             'test_resources',
                             'csvfiles/',)
TEST_CSV_SCRUB_PATH = os.path.join(os.path.dirname(pivot.__file__),
                                   'test',
                                   'test_resources',
                                   'csvfiles/scrub/pre_scrub/',)

TEST_CSV_POST_SCRUB_PATH = os.path.join(os.path.dirname(pivot.__file__),
                                        'test',
                                        'test_resources',
                                        'csvfiles/scrub/post_scrub/',)
TEST_CSV_URL = urljoin('file://', TEST_CSV_PATH)

# Format: (query_str, expected status code)
ENDPOINT_TEST_CASES = [
    ("?end_qtr=mn", 400),
    ("?end_yr=1342", 400),
    ("?end_yr=letters", 400),
    ("?num_qtrs=-1", 400),
    ("?num_qtrs=letters", 400),
    ("?end_qtr=au&end_yr=12&num_qtrs=8", 200),
    ("?end_qtr=au&end_yr=12", 200),
    ("?end_qtr=au&num_qtrs=8", 200),
    ("?end_yr=12&num_qtrs=8", 200),
    ("?num_qtrs=8", 200),
    ("?end_qtr=au", 200),
    ("?end_yr=12", 200),
    ("?end_qtr=sp&end_yr=12&num_qtrs=8", 416),
    ("?end_qtr=au&end_yr=14&num_qtrs=8", 416),
    ("?end_qtr=au&end_yr=12&num_qtrs=27", 416),
    ("?end_qtr=au&end_yr=12", 200),
    ("?end_qtr=au&num_qtrs=8", 200),
    ("?end_yr=12&num_qtrs=8", 200),
    ("?num_qtrs=8", 200),
    ("?end_qtr=au", 200),
    ("?end_yr=12", 200),
]

# To be used on scrub tests (make sure &'s are replaced with _AND_)
scrubbed_major = b'PB_AND_J_10'


class CsvDataApiTest(TestCase):
    """ Tests the api/v1 CSV apis
    """
    def setUp(self):
        self.user = User.objects.create(username='testuser')
        self.user.save()

        self.client.force_login(user=self.user)
        session = self.client.session
        session['samlUserdata'] = {
            "isMemberOf": [settings.PIVOT_AUTHZ_GROUPS['access']]
        }
        session.save()

    def tearDown(self):
        self.user.delete()

    @override_settings(MEDIA_ROOT=TEST_CSV_PATH)
    def test_major_course_path(self):
        self._major_course()

    @override_settings(MEDIA_ROOT=TEST_CSV_URL)
    def test_major_course_url(self):
        self._major_course()

    @override_settings(MEDIA_ROOT=TEST_CSV_PATH)
    def test_data_map_path(self):
        self._data_map()

    @override_settings(MEDIA_ROOT=TEST_CSV_URL)
    def test_data_map_url(self):
        self._data_map()

    @override_settings(MEDIA_ROOT=TEST_CSV_PATH)
    def test_status_lookup_path(self):
        self._status_lookup()

    @override_settings(MEDIA_ROOT=TEST_CSV_URL)
    def test_status_lookup_url(self):
        self._status_lookup()

    @override_settings(MEDIA_ROOT=TEST_CSV_PATH)
    def test_student_data_path(self):
        self._student_data()

    @override_settings(MEDIA_ROOT=TEST_CSV_URL)
    def test_student_data_url(self):
        self._student_data()

    @override_settings(MEDIA_ROOT=TEST_CSV_PATH)
    def test_major_course_query_parameters(self):
        for test_case in ENDPOINT_TEST_CASES:
            url = '/api/v1/major_course/' + test_case[0]
            response = self.client.get(url)
            self.assertTrue(response.status_code == test_case[1])

    @override_settings(MEDIA_ROOT=TEST_CSV_PATH)
    def test_student_data_query_parameters(self):
        for test_case in ENDPOINT_TEST_CASES:
            url = '/api/v1/student_data/' + test_case[0]
            response = self.client.get(url)
            self.assertTrue(response.status_code == test_case[1])

    @override_settings(MEDIA_ROOT=TEST_CSV_SCRUB_PATH)
    def test_scrub_major_course(self):
        url = '/api/v1/major_course/'

        file_name = 'au12_8qtrs_majors_and_courses.csv'
        path = os.path.join(TEST_CSV_POST_SCRUB_PATH, file_name)

        with open(path, 'r') as csvfile:
            csv_reader = csv.reader(csvfile)
            file_data = self.csv_to_string(csv_reader)
            file_data = file_data.encode('utf-8')

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        response_data = response.content
        self.assertTrue(file_data == response_data)

    @override_settings(MEDIA_ROOT=TEST_CSV_SCRUB_PATH)
    def test_scrub_status_lookup(self):
        url = '/api/v1/status_lookup/'

        file_name = 'status_lookup.csv'
        path = os.path.join(TEST_CSV_POST_SCRUB_PATH, file_name)

        with open(path, 'r') as csvfile:
            csv_reader = csv.reader(csvfile)
            file_data = self.csv_to_string(csv_reader)
            file_data = file_data.encode('utf-8')

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        response_data = response.content
        self.assertTrue(response_data == file_data)

    @override_settings(MEDIA_ROOT=TEST_CSV_SCRUB_PATH)
    def test_scrub_student_data(self):
        url = '/api/v1/student_data/'

        file_name = 'au12_8qtrs_student_data_all_majors.csv'
        path = os.path.join(TEST_CSV_POST_SCRUB_PATH, file_name)

        with open(path, 'r') as csvfile:
            csv_reader = csv.reader(csvfile)
            file_data = self.csv_to_string(csv_reader)
            file_data = file_data.encode('utf-8')

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        response_data = response.content
        self.assertTrue(response_data == file_data)

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
        file_name = 'au12_8qtrs_majors_and_courses.csv'
        path = os.path.join(TEST_CSV_PATH, file_name)

        with open(path, 'r') as csvfile:
            csv_reader = csv.reader(csvfile)
            data = self.csv_to_string(csv_reader)
            data = data.encode('utf-8')

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertEqual(data, response.content)

    def _data_map(self):
        url = '/api/v1/data_map/'
        file_name = 'data_map.csv'
        path = os.path.join(TEST_CSV_PATH, file_name)
        with open(path, 'r') as csvfile:
            csv_reader = csv.reader(csvfile)
            data = self.csv_to_string(csv_reader)
            data = data.encode('utf-8')

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertEqual(data, response.content)

    def _status_lookup(self):
        url = '/api/v1/status_lookup/'
        file_name = 'status_lookup.csv'
        path = os.path.join(TEST_CSV_PATH, file_name)
        with open(path, 'r') as csvfile:
            csv_reader = csv.reader(csvfile)
            data = self.csv_to_string(csv_reader)
            data = data.encode('utf-8')

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertEqual(data, response.content)

    def _student_data(self):
        url = '/api/v1/student_data/'
        file_name = 'au12_8qtrs_student_data_all_majors.csv'
        path = os.path.join(TEST_CSV_PATH, file_name)
        with open(path, 'r') as csvfile:
            csv_reader = csv.reader(csvfile)
            data = self.csv_to_string(csv_reader)
            data = data.encode('utf-8')

        response = self.client.get(url)
        self.assertTrue(200 == response.status_code)
        self.assertEqual(data, response.content)
