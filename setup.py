import os
from setuptools import setup

README = open(os.path.join(os.path.dirname(__file__), 'README.md')).read()

# allow setup.py to be run from any path
os.chdir(os.path.normpath(os.path.join(os.path.abspath(__file__), os.pardir)))

setup(
    name='pivot',
    version='0.1',
    packages=['pivot'],
    include_package_data=True,
    install_requires=[
        'Django<2.1',
        'django-compressor',
        'django-templatetag-handlebars',
        'UW-Django-SAML2 @ git+ssh://git@github.com/uw-it-aca/uw-django-saml2.git@36f3fde6f68c5400e9b308d7a9d99464958d7165#egg=UW-Django-SAML2'
    ],
    license='Apache License, Version 2.0',  # example license
    description='A Django App for analyzing major/grade data',
    long_description=README,
    url='http://www.example.com/',
    author='Your Name',
    author_email='yourname@example.com',
    classifiers=[
        'Environment :: Web Environment',
        'Framework :: Django',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: Apache Software License',
        'Operating System :: OS Independent',
        'Programming Language :: Python',
        'Programming Language :: Python :: 2.6',
        'Programming Language :: Python :: 2.7',
        'Topic :: Internet :: WWW/HTTP',
        'Topic :: Internet :: WWW/HTTP :: Dynamic Content',
    ],
)
