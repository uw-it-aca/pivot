import os
from setuptools import setup

# README = open(os.path.join(os.path.dirname(__file__), 'README.md')).read()
README = """
See the README on `GitHub
<https://github.com/uw-it-aca/pivot>`_.
"""

# allow setup.py to be run from any path
os.chdir(os.path.normpath(os.path.join(os.path.abspath(__file__), os.pardir)))

setup(
    name='pivot',
    version='0.1',
    packages=['pivot'],
    include_package_data=True,
    install_requires=[
        'Django>=2.0.13,<2.1',
        'django-compressor',
        'python-memcached',
        'django-templatetag-handlebars',
        'django-user-agents',
        'django-storages[google]',
        'UW-Django-SAML2<2.0',
    ],
    license='Apache License, Version 2.0',  # example license
    description='A Django App for analyzing major/grade data',
    long_description=README,
    url='https://github.com/uw-it-aca/pivot',
    author='"UW-IT AXDD"',
    author_email='aca-it@uw.edu',
    classifiers=[
        'Environment :: Web Environment',
        'Framework :: Django',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: Apache Software License',
        'Operating System :: OS Independent',
        'Programming Language :: Python',
        'Programming Language :: Python :: 2.7',
        'Programming Language :: Python :: 3.6',
        'Topic :: Internet :: WWW/HTTP',
        'Topic :: Internet :: WWW/HTTP :: Dynamic Content',
    ],
)
