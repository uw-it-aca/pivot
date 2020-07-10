from django.urls import re_path, include

urlpatterns = [
    re_path(r'^saml/', include('uw_saml.urls')),                                                        
    re_path(r'^', include('pivot.urls')),
]
