FROM ubuntu:16.04
MAINTAINER Jason Rivers <jason@jasonrivers.co.uk>

ENV NAGIOS_UID              115
ENV NAGIOS_GID              120
ENV NAGIOS_HOME             /opt/nagios
ENV NAGIOS_USER             nagios
ENV NAGIOS_GROUP            nagios
ENV NAGIOS_CMDUSER          nagios
ENV NAGIOS_CMDGROUP         nagios
ENV NAGIOS_FQDN             nagios.example.com
ENV NAGIOSADMIN_USER        nagiosadmin
ENV NAGIOSADMIN_PASS        nagios
ENV APACHE_RUN_USER         nagios
ENV APACHE_RUN_GROUP        nagios
ENV NAGIOS_TIMEZONE         Europe/Madrid
ENV DEBIAN_FRONTEND         noninteractive
ENV NG_NAGIOS_CONFIG_FILE   ${NAGIOS_HOME}/etc/nagios.cfg
ENV NG_CGI_DIR              ${NAGIOS_HOME}/sbin
ENV NG_WWW_DIR              ${NAGIOS_HOME}/share/nagiosgraph
ENV NG_CGI_URL              /cgi-bin


ADD GPG-KEY-pagerduty /tmp            
RUN apt-key add /tmp/GPG-KEY-pagerduty      
RUN apt add-repository http://packages.pagerduty.com/pdagent/deb       


RUN  sed -i 's/universe/universe multiverse/' /etc/apt/sources.list  && \
  apt-get update && apt-get install -y \
    iputils-ping              \
    netcat                    \
    dnsutils                  \
    build-essential           \
    automake                  \
    autoconf                  \
    gettext                   \
    m4                        \
    gperf                     \
    snmp                      \
    snmpd                     \
    snmp-mibs-downloader      \
    libgd2-xpm-dev            \
    unzip                     \
    bc                        \
    bsd-mailx                 \
    libnet-snmp-perl          \
    git                       \
    libssl-dev                \
    libcgi-pm-perl            \
    librrds-perl              \
    libgd-gd2-perl            \
    libnagios-object-perl     \
    fping                     \
    libfreeradius-client-dev  \
    libnet-snmp-perl          \
    libnet-xmpp-perl          \
    parallel                  \
    python                    \
    python-pip                \
    tzdata                    \
    libcache-memcached-perl   \
    libdbd-mysql-perl         \
    libdbi-perl               \
    libnet-tftp-perl          \
    libredis-perl             \
    libswitch-perl            \
    libwww-perl               \
    libjson-perl              \
    pdagent-integrations   && \
    apt-get clean

RUN pip install awscli
RUN  ( egrep -i "^${NAGIOS_GROUP}"    /etc/group || groupadd -g $NAGIOS_GID $NAGIOS_GROUP    )        &&  \
  ( egrep -i "^${NAGIOS_CMDGROUP}" /etc/group || groupadd $NAGIOS_CMDGROUP )
RUN  ( id -u $NAGIOS_USER    || useradd --system -u $NAGIOS_UID -d $NAGIOS_HOME -g $NAGIOS_GROUP    $NAGIOS_USER    )  &&  \
  ( id -u $NAGIOS_CMDUSER || useradd --system -d $NAGIOS_HOME -g $NAGIOS_CMDGROUP $NAGIOS_CMDUSER )

## Nagios 4.3.1 has leftover debug code which spams syslog every 15 seconds
## Its fixed in 4.3.2 and the patch can be removed then

ADD nagios-core-4.3.1-fix-upstream-issue-337.patch /tmp/
  
RUN  cd /tmp              &&  \
  git clone https://github.com/NagiosEnterprises/nagioscore.git -b nagios-4.3.1    &&  \
  cd nagioscore            &&  \
  patch -p1 < /tmp/nagios-core-4.3.1-fix-upstream-issue-337.patch  &&  \
  ./configure              \
    --prefix=${NAGIOS_HOME}          \
    --exec-prefix=${NAGIOS_HOME}        \
    --enable-event-broker          \
    --with-command-user=${NAGIOS_CMDUSER}      \
    --with-command-group=${NAGIOS_CMDGROUP}      \
    --with-nagios-user=${NAGIOS_USER}      \
    --with-nagios-group=${NAGIOS_GROUP}    &&  \
  make all            &&  \
  make install            &&  \
  make install-config          &&  \
  make install-commandmode        &&  \
  make clean

RUN  cd /tmp              &&  \
  git clone https://github.com/nagios-plugins/nagios-plugins.git -b release-2.2.1    &&  \
  cd nagios-plugins          &&  \
  ./tools/setup            &&  \
  ./configure              \
    --prefix=${NAGIOS_HOME}        &&  \
  make              &&  \
  make install            &&  \
  make clean  &&  \
  mkdir -p /usr/lib/nagios/plugins  &&  \
  ln -sf /opt/nagios/libexec/utils.pm /usr/lib/nagios/plugins

RUN  cd /tmp              &&  \
  git clone https://github.com/NagiosEnterprises/nrpe.git  -b nrpe-3.1.0  &&  \
  cd nrpe              &&  \
  ./configure              \
    --with-ssl=/usr/bin/openssl        \
    --with-ssl-lib=/usr/lib/x86_64-linux-gnu  &&  \
  make check_nrpe            &&  \
  cp src/check_nrpe ${NAGIOS_HOME}/libexec/    &&  \
  make clean

RUN cd /tmp                           && \
  wget 'http://www.mathias-kettner.de/download/mk-livestatus-1.2.8.tar.gz' && \
  tar xzvf mk-livestatus-1.2.8.tar.gz && \
  cd mk-livestatus-1.2.8              && \
  ./configure --with-nagios4          && \
  make                                && \
  make install

RUN  mkdir -p -m 0755 /usr/share/snmp/mibs              &&  \
  mkdir -p         ${NAGIOS_HOME}/etc/conf.d            &&  \
  mkdir -p         ${NAGIOS_HOME}/etc/monitor            &&  \
  mkdir -p -m 700  ${NAGIOS_HOME}/.ssh              &&  \
  chown ${NAGIOS_USER}:${NAGIOS_GROUP} ${NAGIOS_HOME}/.ssh        &&  \
  touch /usr/share/snmp/mibs/.foo                &&  \
  ln -s /usr/share/snmp/mibs ${NAGIOS_HOME}/libexec/mibs          &&  \
  ln -s ${NAGIOS_HOME}/bin/nagios /usr/local/bin/nagios          &&  \
  download-mibs && echo "mibs +ALL" > /etc/snmp/snmp.conf

ADD nagios/nagios.cfg /opt/nagios/etc/nagios.cfg
ADD nagios/cgi.cfg /opt/nagios/etc/cgi.cfg

RUN echo "use_timezone=${NAGIOS_TIMEZONE}" >> /opt/nagios/etc/nagios.cfg
RUN echo "${NAGIOS_TIMEZONE}" > /etc/timezone
RUN ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime

# Copy example config in-case the user has started with empty var or etc

RUN mkdir -p /orig/var && mkdir -p /orig/etc        &&  \
  cp -Rp /opt/nagios/var/* /orig/var/          &&  \
  cp -Rp /opt/nagios/etc/* /orig/etc/

ADD start.sh /usr/local/bin/start_nagios
ADD reload.sh /usr/local/bin/reload_nagios
RUN chmod +x /usr/local/bin/start_nagios /usr/local/bin/reload_nagios

EXPOSE 80

VOLUME "/opt/nagios/var" "/opt/nagios/etc" "/opt/nagios/libexec" "/var/log/apache2" "/usr/share/snmp/mibs" "/opt/Custom-Nagios-Plugins"

CMD [ "/usr/local/bin/start_nagios" ]
