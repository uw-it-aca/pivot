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


WEBPACK_LOADER = {
    'DEFAULT': {
        'BUNDLE_DIR_NAME': 'pivot/bundles/',
        'STATS_FILE': os.path.join(BASE_DIR, 'pivot', 'static', 'webpack-stats.json'),
    }
}

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


