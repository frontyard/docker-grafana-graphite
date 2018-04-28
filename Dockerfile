FROM        ubuntu:18.04
MAINTAINER  frontyard

# ------------- #
#   Variables   #
# ------------- #

ARG DEBIAN_FRONTEND=noninteractive

ENV DEBIAN_FRONTEND noninteractive
ENV GRAPHITE_VERSION=1.1.3 \
    STATS_VERSION=v0.8.0 \
    TWISTED_VERSION=17.9.0 \
    GRAFANA_VERSION=5.1.0

# ---------------- #
#   Installation   #
# ---------------- #

# Install all prerequisites
RUN apt-get update
RUN apt-get -y install apt-utils software-properties-common
RUN apt-get -y update
RUN apt-get -y install python-django-tagging python-simplejson python-memcache \
    python-ldap python-cairo python-pysqlite2 python-pip gunicorn supervisor \
    nginx-light git wget curl openjdk-8-jre build-essential python-dev libffi-dev
RUN apt-get autoclean
RUN apt-get clean
RUN apt-get autoremove

RUN pip install Twisted==$TWISTED_VERSION
RUN pip install pytz

RUN	curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get install -y nodejs
RUN npm install -g wizzy

# Checkout the stable branches of Graphite, Carbon and Whisper and install from there

RUN mkdir -p /src \
    && git clone https://github.com/graphite-project/whisper.git /src/whisper \
    && cd /src/whisper \
    && git checkout $GRAPHITE_VERSION \
    && python setup.py install

RUN git clone https://github.com/graphite-project/carbon.git /src/carbon \
    && cd /src/carbon \
    && git checkout $GRAPHITE_VERSION \
    && python setup.py install

RUN git clone https://github.com/graphite-project/graphite-web.git /src/graphite-web \
    && cd /src/graphite-web \
    && git checkout $GRAPHITE_VERSION \
    && python setup.py install \
    && pip install -r requirements.txt \
    && python check-dependencies.py

# Install StatsD
RUN git clone https://github.com/etsy/statsd.git /src/statsd \
    && cd /src/statsd \
    && git checkout $STATSD_VERSION

# Install Grafana
RUN mkdir /src/grafana \
    && mkdir /opt/grafana \
    && wget https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana-${GRAFANA_VERSION}.linux-x64.tar.gz -O /src/grafana.tar.gz \
    && tar -xzf /src/grafana.tar.gz -C /opt/grafana --strip-components=1 \
    && rm /src/grafana.tar.gz

# ----------------- #
#   Configuration   #
# ----------------- #

# Confiure StatsD
ADD ./statsd/config.js /src/statsd/config.js

# Configure Whisper, Carbon and Graphite-Web
ADD ./graphite/initial_data.json /opt/graphite/webapp/graphite/initial_data.json
ADD ./graphite/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
ADD ./graphite/carbon.conf /opt/graphite/conf/carbon.conf
ADD ./graphite/storage-schemas.conf /opt/graphite/conf/storage-schemas.conf
ADD ./graphite/storage-aggregation.conf /opt/graphite/conf/storage-aggregation.conf

RUN mkdir -p /opt/graphite/storage/whisper \
    && touch /opt/graphite/storage/graphite.db /opt/graphite/storage/index \
    && chown -R www-data /opt/graphite/storage \
    && chmod 0775 /opt/graphite/storage /opt/graphite/storage/whisper \
    && chmod 0664 /opt/graphite/storage/graphite.db \
    && cp /src/graphite-web/webapp/manage.py /opt/graphite/webapp \
    && cd /opt/graphite/webapp/ \
    && python manage.py migrate --run-syncdb --noinput

# Configure Grafana
ADD ./grafana/custom.ini /opt/grafana/conf/custom.ini

RUN	cd /src \
	&& wizzy init \
	&& extract() { cat /opt/grafana/conf/custom.ini | grep $1 | awk '{print $NF}'; } \
	&& wizzy set grafana url $(extract ";protocol")://$(extract ";domain"):$(extract ";http_port")	\		
	&& wizzy set grafana username $(extract ";admin_user")	\
	&& wizzy set grafana password $(extract ";admin_password")

# Add the default dashboards
RUN mkdir /src/datasources \
    && mkdir /src/dashboards
ADD	./grafana/datasources/* /src/datasources
ADD ./grafana/dashboards/* /src/dashboards/
ADD ./grafana/export-datasources-and-dashboards.sh /src/

# Configure nginx and supervisord
ADD ./nginx/nginx.conf /etc/nginx/nginx.conf
ADD ./supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# ---------------- #
#   Expose Ports   #
# ---------------- #

# Grafana
EXPOSE  80

# Graphite
EXPOSE 2003

# StatsD UDP port
EXPOSE  8125/udp

# StatsD Management port
EXPOSE  8126

# Elasticsearch data storage path: /var/lib/elasticsearch
# Graphite data storage path: /opt/graphite/storage/whipsper
# Graphite log path: /opt/graphite/storage/log
# Graphite conf path: /opt/graphite/conf
# Supervisor log path: /var/log/supervisor
# VOLUME  ["/var/lib/elasticsearch", "/opt/graphite/storage/whisper", "/opt/graphite/storage/log", "/opt/graphite/conf", "/var/log/supervisor"]

# -------- #
#   Run!   #
# -------- #

CMD ["/usr/bin/supervisord", "--configuration", "/etc/supervisor/conf.d/supervisord.conf"]
