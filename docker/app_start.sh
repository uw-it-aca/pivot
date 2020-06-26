#!/bin/bash

python manage.py makemigrations
python manage.py migrate
python manage.py initadmin --username test1 --password test1234 --noinput --email 'abcdef@gmail.com'