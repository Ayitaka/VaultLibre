#!/bin/bash

# Add '--no-random-sleep-on-renew' to certbot renews in run.sh to skip the random sleep when renewing
#
# Place in ${HOME}/bwdata/scripts/ and add to crontab after updates.
#
# Example crontab:
#
# #### VaultLibre Sun. Tues, Wed, Thur, Fri, Sat
# 22 2 * * 0,2-6 cd ${HOME} && ./vaultlibre.sh auto update recreate localtime >/dev/null && ${HOME}/bwdata/scripts/patch-run.sh >/dev/null
#
# #### VaultLibre Mon force restart to allow updating LetsEncrypt if necessary
# 22 2 * * 1 cd ${HOME} && ./vaultlibre.sh auto update recreate localtime restart >/dev/null && ${HOME}/bwdata/scripts/patch-run.sh >/dev/null
#
# Credit to dlundgren for suggesting this and originally trying to add a proper PR for this (https://github.com/bitwarden/server/pull/1766)

sed -iE 's/ renew --logs-dir/ renew --no-random-sleep-on-renew --logs-dir/' ${HOME}/bwdata/scripts/run.sh

