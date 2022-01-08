# Copyright 2022 UW-IT, University of Washington
# SPDX-License-Identifier: Apache-2.0

"""
Tests context processors.
"""

from django.test import TestCase, RequestFactory
from pivot.context_processors import google_analytics


class ContextProcessorTest(TestCase):
    def test_google_analytics_processor(self):
        with self.settings(GOOGLE_ANALYTICS_KEY='mykey-01-test'):
            factory = RequestFactory()
            req = factory.get('/')
            expected = {'GOOGLE_ANALYTICS_KEY': 'mykey-01-test',
                        'google_analytics': 'mykey-01-test'}

            out = google_analytics(req)

            self.assertEqual(expected, out)
