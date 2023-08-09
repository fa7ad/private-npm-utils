# private-npm-utils

Useful utilities for managing private npm registries (like Nexus, Verdaccio. etc).

## Utilities

The following utilities are currently open-sourced:

### rescope_pkg.sh

#### Purpose

Rescopes a tarball's package.json to a new scope.
This is useful when you want to publish a package to a private registry,
but the package.json's `name` field is unscoped, or using a different scope.
This helps with using different scopes for different registries, and also helps
with publishing packages to the public registry.

#### Usage

```bash
$ ./rescope_pkg.sh -h

Usage:
rescope_pkg [-r REGISTRY_URL] [-s SCOPE] PACKAGE_URL
   -r [registry_url] : set the registry url to use in publishConfig
   -s [scope]        : set the scope to use, defaults to private (@private/)
   <package_url>     : the url to the package tarball
You can also set REGISTRY_URL, PACKAGE_URL and SCOPE as environment variables
This might be useful for piping, usage in CI, etc.

$ ./rescope_pkg.sh -r https://vdc1.internal.tld/my-suborg -s my-suborg https://nexus1.internal.tld/@suborg1/abc-next.tgz

# my-suborg-abc-1.0.0.tgz will be created in the current directory,
# With the package.json's name field set to @my-suborg/abc
# and the publishConfig set to use the registry https://vdc1.internal.tld/my-suborg
# You can now publish this package to the registry

$ npm publish my-suborg-abc-1.0.0.tgz
```
