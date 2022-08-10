#!/bin/bash

ENV_FILE=~/.sql-ledger.local.env
LINK=.env


if [ -r $ENV_FILE ]; then
    echo "Environment file exists: $ENV_FILE" 1>&2
else
    cat >$ENV_FILE <<EOF
###############################
# You may want to adjust these:
###############################

LEDGER_PORT=4293
LEDGERSETUP_CONFIG_PATH=
LEDGERSETUP_DUMP_PATH=


###################################
# These shoud be ok for most of us:
###################################

COMPOSE_PROJECT_NAME=sql-ledger

LEDGER_DOCUMENT_ROOT=/srv/www/sql-ledger
LEDGER_POSTGRES_USER=sql-ledger

LEDGER_APACHE_RUN_USER=$(id -un)
LEDGER_APACHE_RUN_USERID=$(id -u)
LEDGER_APACHE_RUN_GROUP=$(id -gn)
LEDGER_APACHE_RUN_GROUPID=$(id -g)
EOF
    echo "Environment file created: $ENV_FILE" 1>&2
    echo "Please adjust it to your needs." 1>&2
fi
    
if [ -L $LINK ]; then
    echo "Symbolic link exists: $LINK" 1>&2
else
    ln -s $ENV_FILE $LINK
    echo "Symbolic link created: $LINK -> $(readlink -- "$LINK")" 1>&2
fi
