import mock

from django.conf import settings
from django.contrib.auth import authenticate, login
from django.contrib.auth.models import User
from django.core.exceptions import ImproperlyConfigured
from django.contrib.sessions.middleware import SessionMiddleware
from django.http import HttpResponseRedirect
from django.contrib.sessions.models import Session
from django.test import TestCase, RequestFactory, override_settings
from django.urls import reverse

from uw_saml.auth import DjangoSAML, OneLogin_Saml2_Auth
from uw_saml.tests import MOCK_SAML_ATTRIBUTES, UW_SAML_MOCK,\
                          UW_SAML_MOCK_WITH_AUTO_LOGIN
from uw_saml.views import _isMockSamlBackend, login_views_selector


@override_settings(
    AUTHENTICATION_BACKENDS=['uw_saml.backends.SamlMockModelBackend'],
    UW_SAML_MOCK=UW_SAML_MOCK
)
class DjangoLoginAuthTest(TestCase):
    def setUp(self):
        self.request = RequestFactory().post(reverse('saml_login'))
        SessionMiddleware().process_request(self.request)
        self.request.session.save()

    def test_switcher(self):
        self.assertTrue(_isMockSamlBackend())

    def test_authenticate(self):
        # Assert valid password - user1
        self.assertTrue(authenticate(
            self.request,
            username=UW_SAML_MOCK['SAML_USERS'][0]['username'],
            password=UW_SAML_MOCK['SAML_USERS'][0]['password'])
        )

        # Assert invalid password - user1
        self.assertFalse(authenticate(
            self.request,
            username=UW_SAML_MOCK['SAML_USERS'][0]['username'],
            password=(UW_SAML_MOCK['SAML_USERS'][0]['password'] + "_wrong"))
        )

        # Test user 2
        self.assertTrue(authenticate(
            self.request,
            username=UW_SAML_MOCK['SAML_USERS'][1]['username'],
            password=UW_SAML_MOCK['SAML_USERS'][1]['password'])
        )

    def test_samlUserdata(self):
        self.assertTrue(authenticate(
            self.request,
            username=UW_SAML_MOCK['SAML_USERS'][0]['username'],
            password=UW_SAML_MOCK['SAML_USERS'][0]['password'])
        )

        self.assertTrue('samlUserdata' in self.request.session)
        self.assertEqual(
            self.request.session['samlUserdata'],
            UW_SAML_MOCK['SAML_USERS'][0]['MOCK_ATTRIBUTES']
        )

    @override_settings(UW_SAML_MOCK=False)
    def test_improper_config(self):
        self.assertRaises(
            ImproperlyConfigured,
            authenticate,
            self.request,
            sername=UW_SAML_MOCK['SAML_USERS'][0]['username'],
            password=UW_SAML_MOCK['SAML_USERS'][0]['password']
        )


@override_settings(
    AUTHENTICATION_BACKENDS=['uw_saml.backends.SamlMockModelBackend'],
    UW_SAML_MOCK=UW_SAML_MOCK_WITH_AUTO_LOGIN
)
class AutoLoginAuthTest(TestCase):
    def setUp(self):
        self.request = RequestFactory().get(
            reverse('saml_login') + "/?next=''"
        )
        SessionMiddleware().process_request(self.request)
        self.request.session.save()

    def test_direct_to_redirect(self):
        response = login_views_selector()(self.request)
        self.assertIsInstance(response, HttpResponseRedirect)
        SessionMiddleware().process_response(self.request, response)

        session = Session.objects.get(
            session_key=response.cookies['sessionid'].value
        ).get_decoded()

        user = User.objects.get(id=session.get('_auth_user_id'))
        self.assertEqual(
            user.username,
            settings.UW_SAML_MOCK['AUTO_LOGIN_USER']['username']
        )


class LiveAuthTest(TestCase):
    def setUp(self):
        self.request = RequestFactory().post(
            reverse('saml_sso'), data={'SAMLResponse': ''},
            HTTP_HOST='idp.uw.edu')
        SessionMiddleware().process_request(self.request)
        self.request.session.save()

    @override_settings()
    def test_missing_implementation(self):
        del settings.UW_SAML
        self.assertRaises(ImproperlyConfigured, DjangoSAML, self.request)

    def test_implementation(self):
        auth = DjangoSAML(self.request)
        self.assertIsInstance(auth.one_login, OneLogin_Saml2_Auth)

    def test_switcher(self):
        self.assertFalse(_isMockSamlBackend())

    @mock.patch.object(OneLogin_Saml2_Auth, 'login')
    def test_login(self, mock_login):
        auth = DjangoSAML(self.request)
        url = auth.login(return_to='/test')
        mock_login.assert_called_with(force_authn=False, return_to='/test')

        with self.settings(SAML_FORCE_AUTHN=True):
            auth = DjangoSAML(self.request)
            url = auth.login(return_to='/test')
            mock_login.assert_called_with(force_authn=True, return_to='/test')

    @mock.patch.object(OneLogin_Saml2_Auth, 'get_attributes')
    def test_get_attributes(self, mock_attributes):
        mock_attributes.return_value = MOCK_SAML_ATTRIBUTES

        auth = DjangoSAML(self.request)
        self.assertEquals(auth.get_attributes(), {
            'affiliations': ['student'],
            'eppn': ['javerage@washington.edu'], 'uwnetid': ['javerage'],
            'scopedAffiliations': ['student@washington.edu'],
            'isMemberOf': ['u_test_group', 'u_test2_group']})
