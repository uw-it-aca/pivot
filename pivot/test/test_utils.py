"""
Tests utility scripts
"""

from django.test import TestCase, RequestFactory
from django.test.utils import override_settings
import pivot
from pivot.utils import *


TEST_CSV_PATH = os.path.join(os.path.dirname(pivot.__file__),
                             'test',
                             'test_resources',
                             'csvfiles/',)


class UtilsTest(TestCase):
    @override_settings(CSV_ROOT=TEST_CSV_PATH)
    def test_google_analytics_processor(self):
        self.assertEquals(get_latest_term(), 'au12')
