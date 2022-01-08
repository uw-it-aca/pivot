# Copyright 2022 UW-IT, University of Washington
# SPDX-License-Identifier: Apache-2.0

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
    @override_settings(MEDIA_ROOT=TEST_CSV_PATH)
    def test_get_latest_term(self):
        self.assertEquals(get_latest_term(), 'au12')

    @override_settings(MEDIA_ROOT=TEST_CSV_PATH)
    def test_is_more_recent_true(self):
        self.assertTrue(is_more_recent('au19', 'au18'))

    @override_settings(MEDIA_ROOT=TEST_CSV_PATH)
    def test_is_more_recent_false(self):
        self.assertFalse(is_more_recent('au18', 'au19'))

    @override_settings(MEDIA_ROOT=TEST_CSV_PATH)
    def test_pivot_extras(self):
        template = """
        <a href=".?num_qtrs=8&end_yr=12&end_qtr=AU">
            <strong>Last 2 Years</strong> <br>
            <span>
                AU10 - AU12
            </span>
        </a>
    """
        html = year_select_tab(8)
        self.assertEqual(html, template)
