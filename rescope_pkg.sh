#!/bin/bash

# Copyright 2023 Fahad Hossain
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied. See the License for the specific language governing
# permissions and limitations under the License.

set -eu

if [[ $# -gt 0 ]]; then
  export PACKAGE_URL="$1"
  export SCOPE="$2"
fi

if [[ -z "$PACKAGE_URL" ]]; then
  echo "Usage: $0 <package_tgz_url> [scope]"
  echo "If scope is not provided, it will default to 'private'"
  echo "You can also set PACKAGE_URL and SCOPE as environment variables (useful for piping, CI, etc.)"
  exit 1
fi

SCOPE=${SCOPE:-private}
TAR_NAME=$(basename "$PACKAGE_URL")

current_dir=$(pwd)

for dep in {jq,curl}; do
  if ! command -v "$dep" >/dev/null; then
    echo "$dep is required to run this script"
    exit 1
  fi
done

sponge() {
  perl -ne '
  push @lines, $_;
  END {
    open(OUT, ">$file")
    or die "sponge: cannot open $file: $!\n";
    print OUT @lines;
    close(OUT);
  }
  ' -s -- -file="$1"
}

tmp=$(mktemp -d)

cleanup() {
  echo "Performing cleanup..."
  cd "$current_dir"
  rm -rf "$tmp"
  echo "Cleanup: Done."
}

interrupt() {
  echo -n "Script interrupted. "
  cleanup
  exit 1
}

trap interrupt INT

confirm() {
  echo -n "Press enter to continue, or ctrl-c to cancel. "
  read -r _ans
}

main() {
  cd "$tmp"
  echo "Downloading package archive ${TAR_NAME}..."
  curl -fsSL "$PACKAGE_URL" -o "$TAR_NAME"
  tar xf "$TAR_NAME"

  echo "Adding @${SCOPE} scope to package..."
  cd package
  pkgname=$(jq -r '.name' package.json)

  if [[ "$pkgname" =~ ^@[a-z]+ ]]; then
    update_scoped_package "$pkgname"
  else
    update_package "$pkgname"
  fi

  pack_package

  cd "$current_dir"
}

update_scoped_package() {
  echo 'Warning: updating the name of a scoped package, this may not work properly!'
  confirm
  new_name=$(echo "$1" | sed 's|/|__|' | sed "s|@|@${SCOPE}/|")
  echo "Updating package name to $new_name"
  jq ".name = \"$new_name\"" package.json | sponge package.json
}

update_package() {
  echo "Updating package name to @${SCOPE}/$1"
  jq ".name = \"@${SCOPE}/\" + .name" package.json | sponge package.json
}

pack_package() {
  echo "Packing package..."
  pack_name=$(npm pack --json --pack-destination "$tmp" | jq -r '.[].filename')
  echo "Packing package: Done."

  cp "$tmp/$pack_name" "$current_dir/$pack_name"

  echo "You can now publish the package with:"
  echo "npm publish $pack_name"
}

main "$@"
