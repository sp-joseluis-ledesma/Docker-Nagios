#!/bin/bash

export PATH="/bin:/usr/bin:$PATH"

now=`date +%s`
commandfile="/opt/nagios/var/rw/nagios.cmd"

if [ -p $commandfile ]; then
  printf "[%lu] RESTART_PROGRAM\n" $now > $commandfile
fi

