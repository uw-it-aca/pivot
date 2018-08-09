"""
Miscellaneous unit tests for pivot.
"""

from django.apps import apps
from django.test import TestCase
from pivot.apps import PivotConfig


class PivotConfigTest(TestCase):
    """
    from https://stackoverflow.com/questions/43334953/testing-apps-py-in-django

    At this time, this test really just exists to increase test coverage.
    """
    def test_apps(self):
        self.assertEqual(PivotConfig.name, 'pivot')
        self.assertEqual(apps.get_app_config('pivot').name, 'pivot')
