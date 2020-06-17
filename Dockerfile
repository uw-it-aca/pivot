FROM acait/django-container:1.0.32 as django

USER root
RUN apt-get update && apt-get install libpq-dev -y
RUN apt-get install -y postgresql-client-10
USER acait

ENV PATH="/app/bin:$PATH"

ADD --chown=acait:acait pivot/VERSION /app/pivot/
ADD --chown=acait:acait setup.py /app/
ADD --chown=acait:acait requirements.txt /app/

RUN pip install -r requirements.txt

RUN pip install nodeenv
RUN nodeenv -p 
RUN npm install less -g

ADD --chown=acait:acait . /app/
ADD --chown=acait:acait docker/ project/
# ADD --chown=acait:acait docker/app_deploy.sh /scripts/app_deploy.sh
# ADD --chown=acait:acait docker/app_start.sh /scripts/app_start.sh
# RUN chmod u+x /scripts/app_start.sh
