"""
Tests utility scripts
"""

from django.test import TestCase, RequestFactory
import pivot
from pivot.utils import *


TEST_CSV_PATH = os.path.join(os.path.dirname(pivot.__file__),
                             'test',
                             'test_resources',
                             'csvfiles/',)


class UtilsTest(TestCase):
    def test_google_analytics_processor(self):
        with self.settings(CSV_ROOT=TEST_CSV_PATH):
            self.assertEquals(get_latest_term(), 'au12')
