#!/bin/bash

RETRY="@option.retry@"
JOB_NAME="@job.name@"
LOG_PARENT_DIR='/var/log/salt/job_log'
LOG_DIR="${LOG_PARENT_DIR}/${JOB_NAME}"
SUM_LOG_PATH="${LOG_PARENT_DIR}/${JOB_NAME}.sum"
MINIONS_LOG_PATH="${LOG_DIR}/retry.log"

salt -C 'G@kernelversion:*ubuntu* or *ws*' saltutil.clear_cache --log-level=quiet > /dev/null
salt -C 'G@kernelversion:*ubuntu* or *ws*' saltutil.refresh_pillar --log-level=quiet > /dev/null

echo "Executing with RETRY=${RETRY}"
if [ ${RETRY} == 'false' ];then
salt -v -C 'G@kernelversion:*ubuntu* or *ws*' cmd.run 'unattended-upgrades -d' --summary --out-file=/tmp/salt.log > ${SUM_LOG_PATH}
cat /tmp/salt.log
cat ${SUM_LOG_PATH}
echo "=================DONE===================="
bash /srv/salt/states/minions_management/scripts/get_failed_minions.sh "${JOB_NAME}"
else
while read LINE;do
    echo "Retry with minions failed: ${LINE}"
    salt -v -L "${LINE}" cmd.run 'unattended-upgrades -d' --summary --out-file=/tmp/salt.log > ${SUM_LOG_PATH}
    cat /tmp/salt.log
    cat ${SUM_LOG_PATH}
    bash /srv/salt/states/minions_management/scripts/get_failed_minions.sh "${JOB_NAME}"
done < ${MINIONS_LOG_PATH}
echo "=================DONE===================="
fi
