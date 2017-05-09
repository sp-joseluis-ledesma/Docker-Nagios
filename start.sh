#!/bin/bash

# adapted from https://github.com/discourse/discourse_docker/blob/master/image/base/boot
# this script becomes PID 1 inside the container, catches termination signals, and stops
# processes managed by runit

if [ -z "$(ls -A /opt/nagios/etc)" ]; then
    echo "Started with empty ETC, copying example data in-place"
    cp -Rp /orig/etc/* /opt/nagios/etc/
fi

if [ -z "$(ls -A /opt/nagios/var)" ]; then
    echo "Started with empty VAR, copying example data in-place"
    cp -Rp /orig/var/* /opt/nagios/var/
fi

if [ ! -f ${NAGIOS_HOME}/etc/htpasswd.users ] ; then
  htpasswd -c -b -s ${NAGIOS_HOME}/etc/htpasswd.users ${NAGIOSADMIN_USER} ${NAGIOSADMIN_PASS}
  chown -R nagios.nagios ${NAGIOS_HOME}/etc/htpasswd.users
fi

/opt/nagios/bin/nagios /opt/nagios/etc/nagios.cfg

