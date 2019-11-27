from django.conf.urls import url

from uw_saml.views import login_views_selector, logout_views_selector, SSOView

urlpatterns = [
    url(r'login$', login_views_selector(), name='saml_login'),
    url(r'logout$', logout_views_selector(), name='saml_logout'),
    url(r'sso$', SSOView.as_view(), name='saml_sso'),
]
