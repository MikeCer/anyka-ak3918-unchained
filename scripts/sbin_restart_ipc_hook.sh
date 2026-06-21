#!/bin/sh
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin

killall -15 anyka_ipc
sleep 1
/usr/sbin/start_ipc_hook.sh

exit 0
