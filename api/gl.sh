#!/bin/bash

curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-Key: d1bvbxkI8f1bnMBJ4sZiC-xupl4fOEzf" \
  -d @gl.json \
   https://ledger123.net/api/index.pl/ledger28/sql_post_gl_transaction

