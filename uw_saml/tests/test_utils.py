from django.contrib.sessions.middleware import SessionMiddleware
from django.test import TestCase, RequestFactory
from uw_saml.utils import get_attribute, get_user, is_member_of_group
from uw_saml.tests import MOCK_SESSION_ATTRIBUTES


class UtilsTest(TestCase):
    def setUp(self):
        self.request = RequestFactory().get('/')
        SessionMiddleware().process_request(self.request)
        self.request.session['samlUserdata'] = MOCK_SESSION_ATTRIBUTES

    def test_get_attribute(self):
        self.assertEquals(get_attribute(self.request, 'email'), None)
        self.assertEquals(get_attribute(self.request, 'affiliations'),
                          ['student'])

    def test_get_user(self):
        # no setting, default to uwnetid
        self.assertEquals(get_user(self.request), 'javerage')

        with self.settings(SAML_USER_ATTRIBUTE='uwnetid'):
            self.assertEquals(get_user(self.request), 'javerage')

        with self.settings(SAML_USER_ATTRIBUTE='eppn'):
            self.assertEquals(get_user(self.request),
                              'javerage@washington.edu')

    def test_get_user_without_uwnetid(self):
        self.request.session['samlUserdata'] = {}
        self.assertEquals(get_user(self.request), None)

    def test_get_user_without_saml(self):
        del self.request.session['samlUserdata']
        self.assertEquals(get_user(self.request), None)

    def test_is_member_of_group(self):
        self.assertEquals(is_member_of_group(self.request, 'u_test_group'),
                          True)
        self.assertEquals(is_member_of_group(self.request, 'u_test_nope'),
                          False)
        self.assertEquals(is_member_of_group(self.request, ''), False)
        self.assertEquals(is_member_of_group(self.request, None), False)

    def test_is_member_of_group_without_ismemberof(self):
        self.request.session['samlUserdata'] = {}
        self.assertEquals(is_member_of_group(self.request, 'u_test_group'),
                          False)

    def test_is_member_of_group_without_saml(self):
        del self.request.session['samlUserdata']
        self.assertEquals(is_member_of_group(self.request, 'u_test_group'),
                          False)
