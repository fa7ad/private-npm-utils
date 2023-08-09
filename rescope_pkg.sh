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

colorcode() {
  printf "\033[%sm" "$1"
}

# no color
nc="$(colorcode 0)"
# cyan text
tc="$(colorcode "0;36")"
# bold cyan text
tcb="$(colorcode "1;36")"
# yellow text
ty="$(colorcode "0;33")"

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

usage_exit() {
  cat <<EOF 1>&2
Usage:
${tcb}$(basename "$0")${tc} [-r \$REGISTRY_URL] [-s \$SCOPE] \$PACKAGE_URL${nc}
   ${ty}-r [registry_url] ${nc}: set the registry url to use in ${ty}publishConfig${nc}
   ${ty}-s [scope]        ${nc}: set the scope to use, defaults to private (${ty}@private${nc}/)
   ${ty}<package_url>     ${nc}: the url to the package tarball
You can also set REGISTRY_URL, PACKAGE_URL and SCOPE as environment variables
This might be useful for piping, usage in CI, etc.
EOF

  exit 1
}

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

  echo "Downloading package archive ${ty}${TAR_NAME}${nc} from ${ty}'${PACKAGE_URL}'${nc}..."
  curl -fsSL "$PACKAGE_URL" -o "$TAR_NAME"
  tar xf "$TAR_NAME"

  echo ""
  echo "Adding ${tc}@${SCOPE}${nc} scope to package..."
  cd package
  pkgname=$(jq -r '.name' package.json)

  if [[ "$pkgname" =~ ^@[a-z]+ ]]; then
    update_scoped_package "$pkgname"
  else
    update_package "$pkgname"
  fi

  if [[ -n "$REGISTRY_URL" ]]; then
    update_registry "$REGISTRY_URL"
  fi

  pack_package

  cd "$current_dir"
}

update_scoped_package() {
  echo ""
  echo 'Warning: updating the name of a scoped package, this may not work properly!'
  confirm
  new_name=$(echo "$1" | sed 's|/|__|' | sed "s|@|@${SCOPE}/|")
  echo "Updating package name to $new_name"
  jq ".name = \"$new_name\"" package.json | sponge package.json
}

update_package() {
  echo ""
  echo "Updating package name to ${tcb}@${SCOPE}${tc}/$1${nc}"
  jq ".name = \"@${SCOPE}/\" + .name" package.json | sponge package.json
  echo "Updating package name: Done."
}

update_registry() {
  echo ""
  echo "Updating registry to ${tc}$1${nc}"
  jq ".publishConfig.registry = \"$1\"" package.json | jq '.publishConfig.access = "public"' | sponge package.json
  echo "Updating registry: Done."
}

pack_package() {
  echo ""
  echo "Packing package..."
  pack_name=$(npm pack --json --pack-destination "$tmp" | jq -r '.[].filename')
  echo "Packing package: Done."

  cp "$tmp/$pack_name" "$current_dir/$pack_name"

  cat <<EOF

Package ready to publish!
You can now publish the package with:
${tc}
  npm publish ${tcb}"$pack_name"
${nc}
EOF
}

SCOPE=${SCOPE:-private}
REGISTRY_URL=${REGISTRY_URL:-}
PACKAGE_URL=${PACKAGE_URL:-}

while getopts r:s:h OPT; do
  case $OPT in
  r)
    export REGISTRY_URL="$OPTARG"
    ;;
  s)
    export SCOPE="$OPTARG"
    ;;
  h)
    usage_exit
    ;;
  *)
    break
    ;;
  esac
done

shift $((OPTIND - 1))

if [[ $# -gt 0 ]]; then
  export PACKAGE_URL="$1"
fi

if [[ -z "$PACKAGE_URL" ]]; then
  usage_exit
fi

TAR_NAME=$(basename "$PACKAGE_URL")

current_dir=$(pwd)
tmp=$(mktemp -d)

for dep in {jq,curl}; do
  if ! command -v "$dep" >/dev/null; then
    echo "$dep is required to run this script" 1>&2
    exit 1
  fi
done

main "$@"
