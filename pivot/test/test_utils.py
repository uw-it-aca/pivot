"""
Tests utility scripts
"""
import os

from django.test import TestCase, RequestFactory
from django.test.utils import override_settings

import pivot
from pivot.utils import get_latest_term, is_more_recent
from pivot.templatetags.pivot_extras import year_select_tab


TEST_CSV_PATH = os.path.join(os.path.dirname(pivot.__file__),
                             'test',
                             'test_resources',
                             'csvfiles/',)


class UtilsTest(TestCase):
    @override_settings(CSV_ROOT=TEST_CSV_PATH)
    def test_get_latest_term(self):
        self.assertEquals(get_latest_term(), 'au12')

    @override_settings(CSV_ROOT=TEST_CSV_PATH)
    def test_is_more_recent_true(self):
        self.assertTrue(is_more_recent('au19', 'au18'))

    @override_settings(CSV_ROOT=TEST_CSV_PATH)
    def test_pivot_extras(self):
        template = """
        <a href=".?num_qtrs={0}&end_yr={4}&end_qtr={2}">
            <strong>Last {1} Years</strong> <br>
            <span>
                {2}{3} - {2}{4}
            </span>
        </a>
    """.format(8, 2, 'AU', 10, 12)
        html = year_select_tab(8)
        self.assertEqual(html, template)
