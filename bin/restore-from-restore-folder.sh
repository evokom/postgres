#!/bin/bash

if [ "$(ls -1 ${PG_BACKUP_DUMP_RESTORE} | wc -l)" -gt 1 ] 
then
  echo "-> ${PG_BACKUP_DUMP_RESTORE} CONTAINS MORE THAN 1 FILE! ONLY 0 OR 1 FILES ALLOWED!"
  exit 1
fi

if [ "$(ls -1 ${PG_BACKUP_DUMP_RESTORE} | wc -l)" = 0 ] 
then
  echo "-> NO DUMP TO RESTORE..."
  exit 0
fi

echo "RESTORING DATABASE WITH DATA FROM ${PG_BACKUP_DUMP_RESTORE}"
rm -rf "${PGDATA}"
rm -rf "${PG_BACKUP_BASEBACKUP}"/*
rm -rf "${PG_BACKUP_WAL}"/*

/usr/local/bin/init-db.sh &> /dev/null

runuser --user postgres -- "${PG_BIN}/pg_ctl" -D "${PGDATA}" -o "-c listen_addresses='' -p '5432'"  --wait --timeout="${DATABASE_CHECK_TIME}" --silent --log=/dev/null start

runuser --user postgres -- find "${PG_BACKUP_DUMP_RESTORE}" -type f -name "*.tar" -exec "${PG_BIN}/pg_restore" --dbname="${POSTGRES_DB}" --username="${POSTGRES_USER}" --no-password "{}" \;
if [ "$?" = 0 ] 
then
  rm -rf "${PG_BACKUP_DUMP_RESTORE}"/*
fi

runuser --user postgres -- "${PG_BIN}/pg_ctl" -D "${PGDATA}" -m fast   --wait --timeout="${DATABASE_CHECK_TIME}" --silent stop
