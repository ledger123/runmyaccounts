#!/bin/bash
set -e

createuser -e -U postgres --superuser $LEDGER_POSTGRES_USER
