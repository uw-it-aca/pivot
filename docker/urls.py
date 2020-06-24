from django.urls import re_path, include
from django.contrib.auth import views as auth_views
urlpatterns = [
    re_path(r'^login/$', auth_views.LoginView.as_view(template_name='login.html'), name='login'),                                                            
    re_path(r'^logout/$', auth_views.LogoutView.as_view(next_page='/'), name='logout'),                                                           
    re_path(r'^', include('pivot.urls')),
]
