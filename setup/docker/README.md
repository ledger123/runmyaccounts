# Dockerized SQL-Ledger

## Audience

The content of this directory is addressed at DevOps interested in
Docker-based setups of SQL-Ledger.

## System requirements

* Docker
* `docker-compose`
* For local development: Normal user account with permission to execute Docker commands


## Local development

The goal is to get a SQL-Ledger container that operates directly
on the sources (with a bind mount), so that any change of the sources
will direcly affect the bahaviour of the application.

At the very first time, enter this folder and run

    ./local-env-setup.sh

This will set up a file ~/.sql-ledger.local.env containing
enrironment variables needed for `docker-compose` and a symbolic
link '.env' to this file. The `.env` file is the one that
`docker-compose` is looking for; the linking is just for
persistency reasons. 

For the moment, all settings should be fine. We'll come back to that later.


### Basic development container without containerized database

This is only useful if you have a PostgreSQL database elsewhere. But give it a try &ndash; the scenario is much simpler if problems occur.

Call

    docker-compose -f web.local.yml build

for a first build. If it works trouble-free, then call

    docker-compose -f web.local.yml up -d

If you have to rebuild the image in the future, you could also do that
with a single call:

    docker-compose -f web.local.yml up -d --build --force-recreate


Now the application should be reachable at http://localhost:4293,
but there are no accounts and the admin account is not yet usable.
To initialize, call

    docker-compose -f web.local.yml exec web ledgersetup.pl --initweb

This will setup the application root account with password 'secret'; you can choose another one with `--rootpw PASSWORD`.

After that you can admin-login at http://localhost:4293/admin.pl.


### Standard development container with additional database container

This is the typical use-case.

To restart the application with an additional database container, do:

    docker-compose -f web.local.yml -f db.local.yml up -d --build --force-recreate

Now you could create datasets, create users, ...
The name of the database host is "`db`", the name of the
database user is "`sql-ledger`". (You can change the latter 
in your `.env` file, but if you already have started a database
container you would have to stop it and remove the postgresql
volume before recreating.)

You may prefer to use the convenience script to achieve the same:

    ./ledgerctl up

(Run `./ledgerctl` to get an overview of all possibilities.)

### Working with setups

Now we have an "empty" Ledger application. It would be very useful
to quickly "switch" to different scenarios (datasets + users).
This can be achieved with _setups_.

What you need is a folder for appropriate PostgreSQL dumps and a
folder for setup configs (both somewhere "outside" of this project). Say (for example):

* `~/projects/sql-ledger/ledgersetup/configs`
* `~/projects/sql-ledger/ledgersetup/dumps`

At first you have to configure these in your `~/.sql-ledger.local.env`:

```sh
[...]
LEDGERSETUP_CONFIG_PATH=~/projects/sql-ledger/ledgersetup/configs
LEDGERSETUP_DUMP_PATH=~/projects/sql-ledger/ledgersetup/dumps
[...]
```

Restart the application (because these paths will be bind-mounted read-only into the web container:

    ./ledgerctl up

A setup config is written in YAML. We show this with an example,
say `setup1.yml`:

```yaml
---
dumps:
  - 20190507/somedump.bz2
  - 20190507/someotherdump.bz2
force_recreate: 1
users:
  - { name: de, pass: de, lang: de }
  - { name: gb, pass: gb, lang: gb }
```

The `dumps` are relative paths in your `LEDGERSETUP_DUMP_PATH` folder.

Having that, you could run

    ./ledgerctl setup setup1.yml

After that, you can work with this setup. Besides, you can query the latest setup info via web interface at any time:

    http://localhost:4293/ledgersetup/runinfo


#### Configuration syntax

Aside from what you already have seen in the example above, you can use
the following special patterns in dump paths:

* Shell globbing with "`*`"
* *One* use of the pattern `{{ latest_nonempty_dir() }}`
* Use of the pattern `{{ build_time(%Y%m%d) }}` (or any other `strftime` expression)
* Use of the pattern `{{ param(KEY) }}` (see `ledgersetup.pl --param KEY=VALUE`)
