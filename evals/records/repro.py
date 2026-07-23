"""Standalone reproduction of the four High-severity defects Jeffy found in
kennethreitz/records at HEAD ea4273695cee6da42edf1cb294d1f2a4505470fc
(2026-02-08) under Python 3.11 + SQLAlchemy 2.x.

Run against upstream HEAD: every check prints BUG. Apply fixes.patch from
this directory: every check prints OK.

    git clone https://github.com/kennethreitz/records.git && cd records
    python -m venv venv && venv/bin/pip install -e . pytest
    venv/bin/python path/to/repro.py            # -> 4x BUG
    git apply path/to/fixes.patch
    venv/bin/python path/to/repro.py            # -> 4x OK
"""
import os
import tempfile

import records
from sqlalchemy.pool import QueuePool

status = []


def check(name, ok):
    status.append(ok)
    print("{}: {}".format("OK " if ok else "BUG", name))


tmp = tempfile.mkdtemp()

# 1. Database.query() INSERT must survive close/reopen (silent data loss).
url = "sqlite:///{}".format(os.path.join(tmp, "h1.db"))
db = records.Database(url)
db.query("CREATE TABLE t (a integer)")
db.query("INSERT INTO t VALUES (1)")
db.close()
db = records.Database(url)
check("query() INSERT persists across reopen",
      [r.a for r in db.query("SELECT * FROM t").all()] == [1])
db.close()

# 2. Database.bulk_query() must survive close/reopen (silent data loss).
url = "sqlite:///{}".format(os.path.join(tmp, "h2.db"))
db = records.Database(url)
db.query("CREATE TABLE t (a integer)")
db.bulk_query("INSERT INTO t VALUES (:a)", [{"a": 1}, {"a": 2}])
db.close()
db = records.Database(url)
check("bulk_query() persists across reopen",
      sorted(r.a for r in db.query("SELECT * FROM t").all()) == [1, 2])
db.close()

# 3. transaction() must propagate exceptions, not swallow them.
db = records.Database("sqlite:///:memory:")
try:
    with db.transaction():
        raise RuntimeError("boom")
except RuntimeError:
    check("transaction() propagates exceptions", True)
else:
    check("transaction() propagates exceptions", False)
db.close()

# 4. query() must not leak pooled connections.
db = records.Database("sqlite:///:memory:", poolclass=QueuePool,
                      pool_size=1, max_overflow=1, pool_timeout=2)
try:
    for _ in range(5):
        db.query("SELECT 1").all()
    check("no pooled-connection leak (5 queries, size-1 pool)", True)
except Exception:
    check("no pooled-connection leak (5 queries, size-1 pool)", False)
db.close()

raise SystemExit(0 if all(status) else 1)
