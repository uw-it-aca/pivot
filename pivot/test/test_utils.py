"""
Tests utility scripts
"""
import os

from django.test import TestCase, RequestFactory
from django.test.utils import override_settings

import pivot
from pivot.utils import get_latest_term


TEST_CSV_PATH = os.path.join(os.path.dirname(pivot.__file__),
                             'test',
                             'test_resources',
                             'csvfiles/',)


class UtilsTest(TestCase):
    @override_settings(CSV_ROOT=TEST_CSV_PATH)
    def test_get_latest_term(self):
        self.assertEquals(get_latest_term(), 'au12')
