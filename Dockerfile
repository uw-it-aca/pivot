FROM acait/django-container:1.1.3 as app-container

ADD --chown=acait:acait pivot/VERSION /app/pivot/
ADD --chown=acait:acait setup.py /app/
ADD --chown=acait:acait requirements.txt /app/
RUN . /app/bin/activate && pip install -r requirements.txt

ADD --chown=acait:acait . /app/
ADD --chown=acait:acait docker/ project/

RUN . /app/bin/activate && pip install nodeenv && nodeenv -p &&\
    npm install -g npm && ./bin/npm install less -g

RUN . /app/bin/activate && python manage.py collectstatic --noinput &&\
    python manage.py compress -f

FROM acait/django-test-container:1.1.3 as app-test-container

COPY --from=0 /app/ /app/
COPY --from=0 /static/ /static/
