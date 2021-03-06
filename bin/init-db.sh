#!/bin/bash

HELP="
This script initializes a new Postgres Database in the \$PGDATA (current: $PGDATA) Folder.
The User is taken from the variable \$POSTGRES_USER and the Password from \$POSTGRES_PASSWORD

An Initial DB can be created if this script is called with the \"--create-db=<DB_NAME>\" flag.
"
CREATE_DATABASE="true"

POSITIONAL=()
while [[ $# > 0 ]]; do
  case "$1" in
    -h|--help)
    echo "${HELP}"
    exit 0
    shift # shift once since flags have no values
    ;;
    --no-create-db)
    CREATE_DATABASE="false"
    shift
    ;;
    *) # unknown flag/switch
    POSITIONAL+=("$1")
    shift
    ;;
  esac
done

set -- "${POSITIONAL[@]}" # restore positional params



function create_db_directories()
{
  mkdir -p "$PGDATA"
  chmod 700 "$PGDATA"
  chown postgres:postgres "$PGDATA"

  # allow the container to be started with `--user`
	if [ "$user" = '0' ]; then
		find "$PGDATA" \! -user postgres -exec chown postgres '{}' +
		find /var/run/postgresql \! -user postgres -exec chown postgres '{}' +
	fi

  echo "-> DATABASE DIRECTORIES CREATED"
}

function init_db()
{
  # init db
  local PW_FILE="/var/lib/postgresql/pw"
  runuser --user postgres -- touch "${PW_FILE}" && echo "$POSTGRES_PASSWORD" >> "${PW_FILE}"
  runuser --user postgres -- "${PG_BIN}/initdb" --username="${POSTGRES_USER}" --pwfile="${PW_FILE}" --pgdata="${PGDATA}"
  runuser --user postgres -- rm "${PW_FILE}"

  # fix config before start
  /usr/local/bin/postgres-conf.sh

  echo "-> DATABASE INITIALIZED"
}

function pg_hba_conf_setup()
{
  if [ "$POSTGRES_HOST_AUTH_METHOD" = 'trust' ]; then
    echo '-> warning trust is enabled for all connections'
    echo '-> see https://www.postgresql.org/docs/12/auth-trust.html'
  fi

  echo "host all all all $POSTGRES_HOST_AUTH_METHOD" >> "$PGDATA/pg_hba.conf"

  echo "-> POSTGRES pg_hba.conf CONFIGURED"
}

function create_db()
{
  runuser --user postgres -- "${PG_BIN}/pg_ctl" -D "${PGDATA}" -o "-c listen_addresses='' -p '5432'"  --wait --timeout="${DATABASE_CHECK_TIME}" --silent --log=/dev/null start

  runuser --user postgres -- /usr/bin/createdb --owner="${POSTGRES_USER}" --user="${POSTGRES_USER}" --no-password "${POSTGRES_DB}"
  echo "-> DATABASE ${POSTGRES_DB} CREATED"

  runuser --user postgres -- "${PG_BIN}/pg_ctl" -D "${PGDATA}" -m fast --wait --timeout="${DATABASE_CHECK_TIME}" --silent stop
}

create_db_directories
init_db
pg_hba_conf_setup

if [  "${CREATE_DATABASE}" = "true" ] 
then
  create_db
fi