#!/bin/sh
#
# Example script used to execute an alert action.
#
#  - in CPU alerts the current value is the last 15min load average
#  - in FS alerts the current value is the root filesystem usage (%)
#

if [ $# != 3 ] ; then
	echo "$0: Wrong number of parameters."
	exit 1
fi

ALERT_TIMEINTVL=$1
ALERT_THRESHOLD=$2
current_value=$3

(
cat << EOF
Message from hostname '$HOSTNAME'

This system is reaching/exceeding the defined $ALERT_THRESHOLD threshold during the last $ALERT_TIMEINTVL seconds.

The current value is: $current_value

Please take proper actions to correct this situation.
EOF
) | mail -s "WARNING: Monitorix alert!" root

