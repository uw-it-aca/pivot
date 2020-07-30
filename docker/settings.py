from .base_settings import *
import os
from django.urls import reverse_lazy


ALLOWED_HOSTS = ['*']

if os.getenv("ENV") == "localdev":
    DEBUG = True
else:
    DEBUG = False


INSTALLED_APPS += [
    'pivot', 'templatetag_handlebars', 'compressor',
    'django.contrib.humanize',
    'django_user_agents',
]

CSV_ROOT = os.path.join(BASE_DIR, "data/")
STATIC_ROOT = 'static/'
COMPRESS_ROOT = 'static/'


COMPRESS_PRECOMPILERS = (('text/less', 'lessc {infile} {outfile}'),)

STATICFILES_FINDERS = (
    'django.contrib.staticfiles.finders.FileSystemFinder',
    'django.contrib.staticfiles.finders.AppDirectoriesFinder',
    'compressor.finders.CompressorFinder',
)


TEMPLATES[0]['OPTIONS']['context_processors'].append('pivot.context_processors.google_analytics')


GOOGLE_ANALYTICS_KEY = os.getenv("GOOGLE_ANALYTICS_KEY", default=" ")

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

PIVOT_AUTHZ_GROUPS = {
    'access': os.getenv("PIVOT_ACCESS_GROUP", 'u_test_access')
}

if os.getenv("AUTH", "NONE") == "SAML_MOCK":
    MOCK_SAML_ATTRIBUTES['isMemberOf'] = [
        PIVOT_AUTHZ_GROUPS['access'],
    ]
elif os.getenv("AUTH", "NONE") == "SAML_DJANGO_LOGIN":
    DJANGO_LOGIN_MOCK_SAML['SAML_USERS'][0]['MOCK_ATTRIBUTES']['isMemberOf'] = [
        PIVOT_AUTHZ_GROUPS['access'],
    ]