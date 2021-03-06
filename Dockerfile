# Richie A FUN CMS for Open edX
#
# Nota bene:
#
# this container expects two volumes for statics and media files (that will be
# served by nginx):
#
# * /data/media
# * /data/static
#
# Once mounted, you will need to collect static files via the eponym django
# admin command:
#
#     python sandbox/manage.py collectstatic
#

# ---- Base image to inherit from ----
FROM python:3.7-stretch as base

# ---- Front-end builder image ----
FROM node:10 as front-builder

# Copy frontend app sources
COPY ./src/frontend /builder/src/frontend

WORKDIR /builder/src/frontend

RUN yarn install --frozen-lockfile && \
    yarn build-production && \
    yarn sass-production

# ---- Back-end builder image ----
FROM base as back-builder

WORKDIR /builder

# Copy required python dependencies
COPY setup.py setup.cfg MANIFEST.in /builder/
COPY ./src/richie /builder/src/richie/

# Copy distributed application's statics
COPY --from=front-builder \
    /builder/src/richie/static/richie/js \
    /builder/src/richie/static/richie/js
COPY --from=front-builder \
    /builder/src/richie/static/richie/css/main.css \
    /builder/src/richie/static/richie/css/main.css

# Upgrade pip to its latest release to speed up dependencies installation
RUN pip install --upgrade pip

RUN mkdir /install && \
    pip install --prefix=/install .[sandbox]

# ---- Core application image ----
FROM base as core

# Install gettext
RUN apt-get update && \
    apt-get install -y \
    gettext vim
    # python3-dev default-libmysqlclient-dev python3-mysqldb
    #&& \
    #rm -rf /var/lib/apt/lists/*

# Copy installed python dependencies
COPY --from=back-builder /install /usr/local

#copy compiled js and css from backbuilder to core
COPY --from=back-builder \
    /builder/src/richie/static/richie/js \
    /app/src/richie/static/richie/js
COPY --from=back-builder \
    /builder/src/richie/static/richie/css/main.css \
    /app/src/richie/static/richie/css/main.css

# Copy runtime-required files
COPY ./sandbox /app/sandbox
COPY ./docker/files/usr/local/bin/entrypoint /usr/local/bin/entrypoint

# Gunicorn
RUN mkdir -p /usr/local/etc/gunicorn
COPY docker/files/usr/local/etc/gunicorn/richie.py /usr/local/etc/gunicorn/richie.py

# Give the "root" group the same permissions as the "root" user on /etc/passwd
# to allow a user belonging to the root group to add new users; typically the
# docker user (see entrypoint).
RUN chmod g=u /etc/passwd

# Un-privileged user running the application
ARG DOCKER_USER
USER ${DOCKER_USER}

# We wrap commands run in this container by the following entrypoint that
# creates a user on-the-fly with the container user ID (see USER) and root group
# ID.
ENTRYPOINT [ "/usr/local/bin/entrypoint" ]

# ---- Development image ----
FROM core as development

# Switch back to the root user to install development dependencies
USER root:root

WORKDIR /app

# Upgrade pip to its latest release to speed up dependencies installation
RUN pip install --upgrade pip

# Copy all sources, not only runtime-required files
COPY . /app/

# Uninstall richie and re-install it in editable mode along with development
# dependencies
RUN pip uninstall -y richie
RUN pip install -e .[dev]
#RUN pip uninstall -y richie
#RUN pip install richie==1.17.0
# RUN pip install mysqlclient

# Install dockerize. It is used to ensure that the database service is accepting
# connections before trying to access it from the main application.
ENV DOCKERIZE_VERSION v0.6.1
RUN curl -sL \
    --output dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz && \
    tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz && \
    rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

# Restore the un-privileged user running the application
ARG DOCKER_USER
USER ${DOCKER_USER}

# Target database host (e.g. database engine following docker-compose services
# name) & port
ENV DB_HOST=mysql \
    DB_PORT=3306

# Run django development server (wrapped by dockerize to ensure the db is ready
# to accept connections before running the development server)
CMD cd sandbox && \
    dockerize -wait tcp://${DB_HOST}:${DB_PORT} -timeout 60s \
    python manage.py runserver 0.0.0.0:8000 

# CMD cd /app/sandbox && \
#     python manage.py makemigrations && \
#     python manage.py migrate 
    #python manage.py collectstatic --no-input && \
    #python manage.py bootstrap_elasticsearch

# ---- Production image ----
FROM core as production
# USER root:root
WORKDIR /app/sandbox

# The default command runs gunicorn WSGI server in the sandbox
CMD gunicorn -c /usr/local/etc/gunicorn/richie.py wsgi:application --preload --log-file=/dev/stdout
