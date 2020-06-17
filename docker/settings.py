from .base_settings import *
import os

ALLOWED_HOSTS = ['*']


INSTALLED_APPS = [
    # 'django_prometheus',
    # 'django.contrib.humanize',
    # 'django_user_agents',
    # 'supporttools',
    # 'rc_django',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'pivot', 'templatetag_handlebars', 'compressor',
]

INSTALLED_APPS += [
    'django_prometheus',
    'django.contrib.humanize',
    'django_user_agents',
    # 'supporttools',
    # 'rc_django',
]

WEBPACK_LOADER = {
    'DEFAULT': {
        'BUNDLE_DIR_NAME': 'pivot/bundles/',
        'STATS_FILE': os.path.join(BASE_DIR, 'pivot', 'static', 'webpack-stats.json'),
    }
}

CSV_ROOT = os.path.join(BASE_DIR, "data/")
LOGIN_REDIRECT_URL = '/'
LOGIN_URL = '/login/'
STATIC_ROOT = 'static/'
COMPRESS_ROOT = 'static/'

COMPRESS_PRECOMPILERS = (('text/less', 'lessc {infile} {outfile}'),)

STATICFILES_FINDERS = (
    'django.contrib.staticfiles.finders.FileSystemFinder',
    'django.contrib.staticfiles.finders.AppDirectoriesFinder',
    'compressor.finders.CompressorFinder',
)

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'project.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'pivot.context_processors.google_analytics',
                # 'supporttools.context_processors.supportools_globals',
            ],
        },
    },
]

# TEMPLATES[0]['OPTIONS']['context_processors'].extend([
#     'supporttools.context_processors.supportools_globals'
# ])

WSGI_APPLICATION = 'project.wsgi.application'

# if not os.getenv("ENV") == "localdev":
#     DATABASES['default']['ENGINE'] = 'django_prometheus.db.backends.mysql'

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

if os.getenv('ENV') == 'localdev':
    DEBUG = True
    RESTCLIENTS_DAO_CACHE_CLASS = None


# Internationalization
# https://docs.djangoproject.com/en/1.11/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_L10N = True

USE_TZ = True

