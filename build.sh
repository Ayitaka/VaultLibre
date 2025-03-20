#!/bin/sh

DIR=`dirname "$0"`
DIR=`exec 2>/dev/null;(cd -- "$DIR") && cd -- "$DIR"|| cd "$DIR"; unset PWD; /usr/bin/pwd || /bin/pwd || pwd`
#BW_VERSION=$(curl -sL https://go.btwrdn.co/bw-sh-versions | grep  '^ *"'coreVersion'":' | awk -F\: '{ print $2 }' | sed -e 's/,$//' -e 's/^"//' -e 's/"$//')
BW_VERSION=$(curl -sL https://raw.githubusercontent.com/bitwarden/self-host/master/version.json | jq -r ".versions.coreVersion")

echo "Building VaultLibre for BitWarden version $BW_VERSION"

# If there aren't any keys, generate them first.
[ -e "$DIR/.keys/cert.cert" ] || "$DIR/.keys/generate-keys.sh"

[ -e "$DIR/src/vaultlibre/.keys" ] || mkdir "$DIR/src/vaultlibre/.keys"

cp "$DIR/.keys/cert.cert" "$DIR/src/vaultlibre/.keys"

docker run --rm -v "$DIR/src/vaultlibre:/vaultlibre" -w=/vaultlibre mcr.microsoft.com/dotnet/sdk:8.0 sh build.sh

docker build --no-cache --build-arg BITWARDEN_TAG=ghcr.io/bitwarden/api:$BW_VERSION --label com.bitwarden.product="vaultlibre" -t vaultlibre/api "$DIR/src/vaultlibre" # --squash
docker build --no-cache --build-arg BITWARDEN_TAG=ghcr.io/bitwarden/identity:$BW_VERSION --label com.bitwarden.product="vaultlibre" -t vaultlibre/identity "$DIR/src/vaultlibre" # --squash

docker tag vaultlibre/api vaultlibre/api:latest
docker tag vaultlibre/identity vaultlibre/identity:latest
docker tag vaultlibre/api vaultlibre/api:$BW_VERSION
docker tag vaultlibre/identity vaultlibre/identity:$BW_VERSION

# Remove old instances of the image after a successful build.
ids=$( docker images vaultlibre/* | grep -E -v -- "CREATED|latest|${BW_VERSION}" | awk '{ print $3 }' )
[ -n "$ids" ] && docker rmi $ids || true
