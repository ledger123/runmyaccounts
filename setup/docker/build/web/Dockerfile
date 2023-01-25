# We cannot use Buster because the included Perl version would nee a change
# throughout the whole code:
# Unimplemented: POSIX::tmpnam(): use File::Temp instead

#FROM debian:buster-slim


FROM debian:stretch

ARG LEDGER_DOCUMENT_ROOT
ARG BUILD_WEB_PATH=.

#RUN sed -ri 's/deb\.debian\.org/ftp.uni-kl.de/g' /etc/apt/sources.list

RUN apt-get update  && \  
    apt-get install -y \
      apache2 \
      libdbi-perl \
      libdbd-pg-perl \
      libdbix-simple-perl \
      libgd-graph-perl \
      libxml-libxml-perl \
      libfile-pushd-perl \
      libfile-type-perl \
      libtext-csv-xs-perl \
      libopenoffice-oodoc-perl \
      libyaml-perl \
      libyaml-tiny-perl \
      libcgi-formbuilder-perl \
      libmojolicious-perl \
      libmojolicious-plugin-i18n-perl \
      libmojo-pg-perl \
      postgresql-client \
      zip \
      bzip2 \
      less

RUN apt-get install -y \
    cpanminus \
    make && \
    cpanm DBIx::XHTML_Table

ARG LEDGER_APACHE_RUN_USER
ARG LEDGER_APACHE_RUN_USERID
ARG LEDGER_APACHE_RUN_GROUP
ARG LEDGER_APACHE_RUN_GROUPID

RUN if test "${LEDGER_APACHE_RUN_USER}" != "www-data"; then \
      groupadd -g ${LEDGER_APACHE_RUN_GROUPID} ${LEDGER_APACHE_RUN_GROUP} && \
      useradd  -u ${LEDGER_APACHE_RUN_USERID} -d /nonexistent -M -r \
               -g ${LEDGER_APACHE_RUN_GROUP} \
               -s /bin/false ${LEDGER_APACHE_RUN_USER}; \
    else \
      echo "APACHE_RUN_USER is www-data -- Nothing to do here"; \
    fi
    

RUN install -d -o ${LEDGER_APACHE_RUN_USER} -g ${LEDGER_APACHE_RUN_GROUP} ${LEDGER_DOCUMENT_ROOT}

ENV APACHE_RUN_DIR=/var/run/apache2 \
    APACHE_PID_FILE=/var/run/apache2/apache2.pid \
    APACHE_RUN_USER=${LEDGER_APACHE_RUN_USER} \
    APACHE_RUN_GROUP=${LEDGER_APACHE_RUN_GROUP} \
    APACHE_LOG_DIR=/var/log/apache2

RUN a2enmod cgi rewrite && \
    a2dissite 000-default && \
    a2disconf other-vhosts-access-log && \
    rm -f /etc/apache2/sites-available/*


COPY ${BUILD_WEB_PATH}/apache_sql-ledger.conf /etc/apache2/sites-available/sql-ledger.conf
COPY ${BUILD_WEB_PATH}/ledger*.pl  /usr/local/bin/

COPY --chown=www-data:www-data . ${LEDGER_DOCUMENT_ROOT}


RUN a2ensite sql-ledger

RUN ln -sf /dev/stderr /var/log/apache2/access.log && \
    ln -sf /dev/stderr /var/log/apache2/error.log

EXPOSE 80




ENV LEDGER_DOCUMENT_ROOT=${LEDGER_DOCUMENT_ROOT} \
    LEDGER_APACHE_RUN_USER=${LEDGER_APACHE_RUN_USER}


CMD ["apache2", "-DFOREGROUND", "-CServerName localhost"]

