# Package

version       = "0.1.0"
author        = "Trim Bresilla"
description   = "bobabrew"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["bobabrew"]

requires "nim >= 2.2.0"

task test, "Run CLI regression tests":
  exec "sh -c 'for t in tests/test_*.nim; do case \"$t\" in *test_support.nim) continue;; esac; nim c -r \"$t\" || exit 1; done'"

