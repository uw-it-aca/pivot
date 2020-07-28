from .base_settings import *
import os

if os.getenv('ENV') == 'localdev':
    DEBUG = True
else:
    DEBUG = False

INSTALLED_APPS += [
    'pivot',
    'templatetag_handlebars',
    'django.contrib.humanize',
    'django_user_agents',
    'compressor',
]

CSV_ROOT = os.getenv('CSV_ROOT', '/data')

COMPRESS_ROOT = '/static/'

COMPRESS_PRECOMPILERS = (
    ('text/less', 'lessc {infile} {outfile}'),
)

COMPRESS_OFFLINE = True

STATICFILES_FINDERS += (
    'compressor.finders.CompressorFinder',
)

TEMPLATES[0]['OPTIONS']['context_processors'].append('pivot.context_processors.google_analytics')

GOOGLE_ANALYTICS_KEY = os.getenv('GOOGLE_ANALYTICS_KEY', ' ')

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
    'access': os.getenv('PIVOT_ACCESS_GROUP', 'u_test_access')
}

if os.getenv('AUTH', 'NONE') == 'SAML_MOCK':
    MOCK_SAML_ATTRIBUTES['isMemberOf'] = [
        PIVOT_AUTHZ_GROUPS['access'],
    ]
elif os.getenv('AUTH', 'NONE') == 'SAML_DJANGO_LOGIN':
    DJANGO_LOGIN_MOCK_SAML['SAML_USERS'][0]['MOCK_ATTRIBUTES']['isMemberOf'] = [
        PIVOT_AUTHZ_GROUPS['access'],
    ]
