# File helper tests

Requires Python 3.9+ and pyftpdlib in a developer test environment. Production
helpers use the standard library only. Run:

```sh
python3 -m venv /path/to/test-env
/path/to/test-env/bin/pip install pyftpdlib
/path/to/test-env/bin/python -m unittest discover -s tools/tests -p test_install_helpers.py -v
```

The suite uses temporary folders and a real FTP server on localhost at a random
port. It never connects to a PS5. It checks separate preparation/transfer, all
seven game layouts, missing/wrong inputs, archive traversal, symlink rejection,
copy hashes, preservation, backups and a server exposing a different SELF SIZE.
Windows/macOS and alternate physical console storage require separate testing.

The validator tests exercise all three preparation modes, missing files, same-size
corruption, wrong title metadata, incorrect nesting, malformed/unsafe/duplicate
manifest entries, symlinks, absent manifests, report preservation and damaged O2R
ZIP CRCs. Verification does not contact a console or change the checked files.
Run both suites with `python -m unittest discover -s tools/tests -p 'test_*.py' -v`
from the repository root. The localhost FTP test needs pyftpdlib; end users do not.

The store-setup suite checks automatic verification, cancellation before any
copy, repeated-run preservation, invalid inputs and the text fallback. Native
Windows/macOS picker behavior is not established by these Linux tests.
