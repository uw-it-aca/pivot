from django.conf import settings
from django.urls import reverse
from django.contrib.sessions.middleware import SessionMiddleware
from django.contrib.auth.views import LoginView, LogoutView
from django.core.exceptions import ImproperlyConfigured
from django.http import HttpResponseRedirect
from django.test import TestCase, RequestFactory, override_settings
from uw_saml.views import SAMLLoginView, SAMLLogoutView, SSOView,\
                          logout_views_selector, login_views_selector
from uw_saml.auth import OneLogin_Saml2_Auth
from uw_saml.tests import MOCK_SAML_ATTRIBUTES, UW_SAML_MOCK,\
                          UW_SAML_MOCK_WITH_AUTO_LOGIN
import mock

CACHE_CONTROL = 'max-age=0, no-cache, no-store, must-revalidate'


class LoginViewTest(TestCase):
    def setUp(self):
        self.request = RequestFactory().get(
            reverse('saml_login') + "/?next=''", HTTP_HOST='example.uw.edu')
        SessionMiddleware().process_request(self.request)
        self.request.session.save()

    def test_login(self):
        view_instance = SAMLLoginView.as_view()
        response = view_instance(self.request)
        self.assertEquals(response.status_code, 302)
        self.assertIn(settings.UW_SAML['idp']['singleSignOnService']['url'],
                      response.url)
        self.assertEquals(response['Cache-Control'], CACHE_CONTROL)

    def test_missing_request_data(self):
        # Missing HTTP_HOST
        request = RequestFactory().get(reverse('saml_login'))
        SessionMiddleware().process_request(request)
        self.request.session.save()

        view_instance = SAMLLoginView.as_view()
        response = view_instance(request)
        self.assertContains(
            response, 'SSO Error: Login Failed', status_code=400)
        self.assertContains(
            response, 'Missing: &#39;HTTP_HOST&#39;', status_code=400)

    def real_view_test(self):
        func = login_views_selector()
        self.assertEqual(func, SAMLLoginView.as_view())

    @override_settings(
        AUTHENTICATION_BACKENDS=['uw_saml.backends.SamlMockModelBackend'],
        UW_SAML_MOCK=UW_SAML_MOCK
    )
    def test_mock_login(self):
        func = login_views_selector()
        self.assertEqual(func.__name__, LoginView.as_view().__name__)

    @override_settings(
        AUTHENTICATION_BACKENDS=['uw_saml.backends.SamlMockModelBackend'],
        UW_SAML_MOCK=UW_SAML_MOCK_WITH_AUTO_LOGIN
    )
    def test_mock_auto_login(self):
        response = login_views_selector()(self.request)
        self.assertIsInstance(response, HttpResponseRedirect)

    @override_settings(
        AUTHENTICATION_BACKENDS=['uw_saml.backends.SamlMockModelBackend'],
    )
    def test_improper_config(self):
        self.assertRaises(
            ImproperlyConfigured,
            login_views_selector
        )


class LogoutViewTest(TestCase):
    def setUp(self):
        self.request = RequestFactory().get(
            reverse('saml_logout') + "/?next=''", HTTP_HOST='example.uw.edu')
        SessionMiddleware().process_request(self.request)
        self.request.session['samlNameId'] = ''
        self.request.session['samlSessionIndex'] = ''
        self.request.session.save()

    def test_logout(self):
        view_instance = SAMLLogoutView.as_view()
        response = view_instance(self.request)
        self.assertEquals(response.status_code, 302)
        self.assertIn(settings.UW_SAML['idp']['singleLogoutService']['url'],
                      response.url)
        self.assertEquals(response['Cache-Control'], CACHE_CONTROL)

    def test_missing_request_data(self):
        # Missing HTTP_HOST
        request = RequestFactory().get(reverse('saml_logout'))
        SessionMiddleware().process_request(request)
        self.request.session.save()

        view_instance = SAMLLogoutView.as_view()
        response = view_instance(request)
        self.assertContains(
            response, 'SSO Error: Logout Failed', status_code=400)
        self.assertContains(
            response, 'Missing: &#39;HTTP_HOST&#39;', status_code=400)

    def real_view_test(self):
        func = logout_views_selector()
        self.assertEqual(func, SAMLLogoutView.as_view())

    @override_settings(
        AUTHENTICATION_BACKENDS=['uw_saml.backends.SamlMockModelBackend'],
        UW_SAML_MOCK=UW_SAML_MOCK
    )
    def test_mock_logout(self):
        func = logout_views_selector()
        self.assertEqual(func.__name__, LogoutView.as_view().__name__)

    @override_settings(
        AUTHENTICATION_BACKENDS=['uw_saml.backends.SamlMockModelBackend'],
        UW_SAML_MOCK=UW_SAML_MOCK_WITH_AUTO_LOGIN
    )
    def test_mock_auto_logout(self):
        response = logout_views_selector()(self.request)
        self.assertIsInstance(response, HttpResponseRedirect)


class SSOViewTest(TestCase):
    def setUp(self):
        self.request = RequestFactory().post(
            reverse('saml_sso'),
            data={'RelayState': '/private'},
            HTTP_HOST='example.uw.edu')
        SessionMiddleware().process_request(self.request)
        self.request.session.save()

    @mock.patch.object(OneLogin_Saml2_Auth, 'get_attributes')
    @mock.patch.object(OneLogin_Saml2_Auth, 'process_response')
    def test_sso(self, mock_process_response, mock_get_attributes):
        mock_get_attributes.return_value = MOCK_SAML_ATTRIBUTES

        view_instance = SSOView.as_view()
        response = view_instance(self.request)
        self.assertEquals(response.status_code, 302)
        self.assertEquals(response.url, 'http://example.uw.edu/private')


class SSOViewErrorTest(TestCase):
    def test_missing_request_data(self):
        # Missing HTTP_HOST
        request = RequestFactory().post(reverse('saml_sso'))
        SessionMiddleware().process_request(request)
        request.session.save()

        view_instance = SSOView.as_view()
        response = view_instance(request)
        self.assertContains(
            response, 'SSO Error: Login Failed', status_code=400)
        self.assertContains(
            response, 'Missing: &#39;HTTP_HOST&#39;', status_code=400)

    def test_missing_post_data(self):
        request = RequestFactory().post(
            reverse('saml_sso'), HTTP_HOST='example.uw.edu')
        SessionMiddleware().process_request(request)
        request.session.save()

        view_instance = SSOView.as_view()
        response = view_instance(request)
        self.assertContains(response, 'SSO Error:', status_code=400)

    def test_invalid_saml_response(self):
        request = RequestFactory().post(
            reverse('saml_sso'), data={'SAMLResponse': ''},
            HTTP_HOST='idp.uw.edu')
        SessionMiddleware().process_request(request)
        request.session.save()

        view_instance = SSOView.as_view()
        response = view_instance(request)
        self.assertContains(response, 'SSO Error:', status_code=400)

    def test_invalid_http_method(self):
        request = RequestFactory().get(
            reverse('saml_sso'), HTTP_HOST='idp.uw.edu')
        SessionMiddleware().process_request(request)
        request.session.save()

        view_instance = SSOView.as_view()
        response = view_instance(request)
        self.assertEquals(response.status_code, 405)
