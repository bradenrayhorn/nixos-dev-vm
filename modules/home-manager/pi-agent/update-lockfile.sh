#!/usr/bin/env bash

# Usage: ./update-lockfile.sh 0.51.2

VERSION="${1}"
NAME="pi-coding-agent"
SCOPE="@mariozechner"
URL="https://registry.npmjs.org/$SCOPE/$NAME/-/$NAME-$VERSION.tgz"

DST=$(pwd)/package-lock.json

echo "=== Work flow for $NAME v$VERSION ==="

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "-> Fetching source..."
curl -sL "$URL" -o "$WORKDIR/source.tgz"

HASH=$(nix hash file "$WORKDIR/source.tgz" --sri)
echo "-> Source Hash: $HASH"

echo "-> Generating package-lock.json..."
tar -xf "$WORKDIR/source.tgz" -C "$WORKDIR"
cd "$WORKDIR/package" || exit 1

npm install --package-lock-only --ignore-scripts

cp package-lock.json "$DST"

echo "=== Done! ==="
echo "1. package-lock.json has been created in this directory."
echo "2. Update 'hash' in your nix file to: $HASH"
echo "3. Run your build, let it fail on 'npmDepsHash', and copy the new hash."
