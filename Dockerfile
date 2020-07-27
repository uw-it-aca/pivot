FROM acait/django-container:1.0.32 as django

USER root
RUN apt-get update && apt-get install libpq-dev -y
RUN apt-get install -y postgresql-client-10
USER acait

ADD --chown=acait:acait pivot/VERSION /app/pivot/
ADD --chown=acait:acait setup.py /app/
ADD --chown=acait:acait requirements.txt /app/

RUN . /app/bin/activate && pip install -r requirements.txt

RUN . /app/bin/activate && pip install nodeenv && nodeenv -p && npm install less -g

ADD --chown=acait:acait . /app/
ADD --chown=acait:acait docker/ project/
