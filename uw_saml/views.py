from django.conf import settings
from django.contrib.auth import authenticate, login, REDIRECT_FIELD_NAME,\
                                get_backends
from django.contrib.auth.views import LoginView, LogoutView
from django.core.exceptions import ImproperlyConfigured
from django.http import HttpResponseRedirect
from django.utils.decorators import method_decorator
from django.views.generic.base import View, TemplateView
from django.views.decorators.cache import never_cache
from django.views.decorators.csrf import csrf_exempt

from uw_saml.auth import DjangoSAML
from uw_saml.backends import SamlMockModelBackend


def _isMockSamlBackend():
    for backend in get_backends():
        if (isinstance(backend, SamlMockModelBackend)):
            return True
    return False


def _auto_login_shunt(request, mock_user):
    user = authenticate(
        request,
        username=mock_user["username"],
        password=mock_user["password"]
    )
    login(request, user)
    return HttpResponseRedirect(request.GET.get('next'))


def login_views_selector():
    if _isMockSamlBackend():
        mock_config = getattr(settings, 'UW_SAML_MOCK', False)
        if mock_config:
            if 'AUTO_LOGIN_USER' in mock_config:
                return lambda request: _auto_login_shunt(
                    request,
                    mock_config['AUTO_LOGIN_USER']
                )
            else:
                return LoginView.as_view(template_name='mock_saml/login.html')
        else:
            raise ImproperlyConfigured('UW_SAML_MOCK not found in settings')
    else:
        return SAMLLoginView.as_view()


def logout_views_selector():
    if _isMockSamlBackend():
        return LogoutView.as_view(template_name='mock_saml/logout.html')
    else:
        return SAMLLoginView.as_view()


class UWSAMLView(TemplateView):
    template_name = 'uw_saml/sso_error.html'


@method_decorator(never_cache, name='dispatch')
class SAMLLoginView(UWSAMLView):
    def get(self, request, *args, **kwargs):
        return_url = request.GET.get(REDIRECT_FIELD_NAME)
        try:
            auth = DjangoSAML(request)
            return HttpResponseRedirect(auth.login(return_to=return_url))
        except KeyError as ex:
            context = {'errors': ['Missing: {}'.format(ex)]}
            return self.render_to_response(context, status=400)


@method_decorator(never_cache, name='dispatch')
class SAMLLogoutView(UWSAMLView):
    def get(self, request, *args, **kwargs):
        try:
            auth = DjangoSAML(request)
            return HttpResponseRedirect(auth.logout())
        except KeyError as ex:
            context = {'error_msg': 'Logout Failed',
                       'errors': ['Missing: {}'.format(ex)]}
            return self.render_to_response(context, status=400)


@method_decorator(csrf_exempt, name='dispatch')
class SSOView(UWSAMLView):
    http_method_names = ['post']

    def post(self, request, *args, **kwargs):
        try:
            auth = DjangoSAML(request)
        except KeyError as ex:
            context = {'errors': ['Missing: {}'.format(ex)]}
            return self.render_to_response(context, status=400)

        try:
            auth.process_response()
        except Exception as ex:
            context = {'error_msg': str(ex),
                       'errors': auth.get_errors()}
            return self.render_to_response(context, status=400)

        errors = auth.get_errors()
        if len(errors):
            return self.render_to_response({'errors': errors}, status=500)

        return_url = request.POST.get('RelayState')
        return HttpResponseRedirect(auth.redirect_to(return_url))
