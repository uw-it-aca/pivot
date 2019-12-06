from django.conf.urls import url, include
from django.contrib.auth import views as auth_views


urlpatterns = [
    url(r'^login/$', auth_views.LoginView.as_view(), {'template_name': 'login.html'},
        name='login'),
    url(r'^logout/$', auth_views.LogoutView.as_view(), {'next_page': '/'},
        name='logout'),
    url(r'^', include('pivot.urls')),
]
