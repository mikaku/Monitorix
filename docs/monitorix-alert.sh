#!/bin/sh
#
# Example script used to execute an alert action.
#
# This script assumes that you symlink your alert scripts like this:
# 	disk.pendsect-alert.sh -> monitorix-alert.sh
# 	disk.realloc-alert.sh -> monitorix-alert.sh
# 	mail.mqueued-alert.sh -> monitorix-alert.sh
# 	system.loadavg-alert.sh -> monitorix-alert.sh
# 	...
# So you only use one script (saving disk space) and its prefix will
# appear in the subject and contents of the email, so you will easily
# identify the source of the alert.
#

MAILTO="root@localhost"

if [ $# != 3 ] && [ $# != 4 ] ; then
	echo "$0: Wrong number of arguments."
	exit 1
fi

ALERT_TIMEINTVL=$1
ALERT_THRESHOLD=$2
current_value=$3
ALERT_WHEN=$4
ALERT=`basename $0 | cut -f1 -d-`

(
cat << EOF
Message from hostname '$HOSTNAME' for '$ALERT' alert.

This system is reaching/exceeding ($ALERT_WHEN) the defined threshold value ($ALERT_THRESHOLD) during the last '$ALERT_TIMEINTVL' seconds.

The current value is: $current_value

Please take proper actions to correct this situation.
EOF
) | mail -s "WARNING: Monitorix alert ($ALERT) from '$HOSTNAME'!" $MAILTO

