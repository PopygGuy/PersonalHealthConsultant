"""Merge duplicated faculties in canonical backend SQLite DB.

Goal:
- keep one logical faculty record;
- relink all dependent rows (groups, users);
- remove empty duplicate rows.

This script is intentionally conservative: it only auto-merges
faculties that look semantically identical after normalization or where
one normalized name is a clear prefix of another and one of them is empty.

Usage:
  python backend/scripts/dedupe_faculties.py
"""

from __future__ import annotations

import sqlite3
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = PROJECT_ROOT / "backend" / "phc.db"


def _normalize_name(name: str) -> str:
    value = (name or "").lower().strip()
    # Normal forms in normal and mojibake variants.
    for token in ("факультет", "���������"):
        value = value.replace(token, " ")
    for ch in ("-", "_"):
        value = value.replace(ch, " ")
    value = " ".join(value.split())
    return value


def _load_faculties(cur: sqlite3.Cursor) -> list[dict]:
    rows = cur.execute(
        """
        SELECT
            f.id,
            f.name,
            (SELECT COUNT(*) FROM groups g WHERE g.faculty_id = f.id) AS group_count,
            (SELECT COUNT(*) FROM users u WHERE u.faculty_id = f.id) AS user_count
        FROM faculties f
        ORDER BY f.name
        """
    ).fetchall()

    data = []
    for row in rows:
        data.append(
            {
                "id": row[0],
                "name": row[1],
                "norm": _normalize_name(row[1]),
                "group_count": int(row[2] or 0),
                "user_count": int(row[3] or 0),
            }
        )
    return data


def _relink_and_delete(cur: sqlite3.Cursor, src_id: str, dst_id: str) -> None:
    if src_id == dst_id:
        return
    cur.execute("UPDATE groups SET faculty_id = ? WHERE faculty_id = ?", (dst_id, src_id))
    cur.execute("UPDATE users SET faculty_id = ? WHERE faculty_id = ?", (dst_id, src_id))
    cur.execute("DELETE FROM faculties WHERE id = ?", (src_id,))


def dedupe() -> dict:
    if not DB_PATH.exists():
        raise FileNotFoundError(f"DB not found: {DB_PATH}")

    conn = sqlite3.connect(str(DB_PATH))
    conn.execute("PRAGMA foreign_keys=ON")
    cur = conn.cursor()

    try:
        faculties = _load_faculties(cur)
        deleted = 0
        relinked_groups = 0
        relinked_users = 0

        consumed: set[str] = set()

        # Pass 1: exact normalized name duplicates -> keep richest record.
        by_norm: dict[str, list[dict]] = {}
        for f in faculties:
            by_norm.setdefault(f["norm"], []).append(f)

        for norm, bucket in by_norm.items():
            if not norm or len(bucket) <= 1:
                continue
            bucket_sorted = sorted(
                bucket,
                key=lambda x: (x["group_count"] + x["user_count"], x["name"]),
                reverse=True,
            )
            keeper = bucket_sorted[0]
            for duplicate in bucket_sorted[1:]:
                if duplicate["id"] in consumed:
                    continue
                before_g = cur.execute("SELECT COUNT(*) FROM groups WHERE faculty_id = ?", (duplicate["id"],)).fetchone()[0]
                before_u = cur.execute("SELECT COUNT(*) FROM users WHERE faculty_id = ?", (duplicate["id"],)).fetchone()[0]
                _relink_and_delete(cur, duplicate["id"], keeper["id"])
                relinked_groups += int(before_g)
                relinked_users += int(before_u)
                deleted += 1
                consumed.add(duplicate["id"])

        # Reload after exact merges.
        faculties = _load_faculties(cur)

        # Pass 2: prefix-like duplicates with one side empty.
        for i, a in enumerate(faculties):
            if a["id"] in consumed or not a["norm"]:
                continue
            for b in faculties[i + 1 :]:
                if b["id"] in consumed or not b["norm"]:
                    continue
                a_in_b = a["norm"] in b["norm"]
                b_in_a = b["norm"] in a["norm"]
                if not (a_in_b or b_in_a):
                    continue

                a_weight = a["group_count"] + a["user_count"]
                b_weight = b["group_count"] + b["user_count"]
                if a_weight == 0 and b_weight == 0:
                    # Keep shorter clearer name, delete the other.
                    keeper = a if len(a["norm"]) <= len(b["norm"]) else b
                    drop = b if keeper is a else a
                elif a_weight == 0 and b_weight > 0:
                    keeper, drop = b, a
                elif b_weight == 0 and a_weight > 0:
                    keeper, drop = a, b
                else:
                    continue

                before_g = cur.execute("SELECT COUNT(*) FROM groups WHERE faculty_id = ?", (drop["id"],)).fetchone()[0]
                before_u = cur.execute("SELECT COUNT(*) FROM users WHERE faculty_id = ?", (drop["id"],)).fetchone()[0]
                _relink_and_delete(cur, drop["id"], keeper["id"])
                relinked_groups += int(before_g)
                relinked_users += int(before_u)
                deleted += 1
                consumed.add(drop["id"])

        conn.commit()

        total_faculties = cur.execute("SELECT COUNT(*) FROM faculties").fetchone()[0]
        result = {
            "deleted_duplicate_faculties": deleted,
            "relinked_groups": relinked_groups,
            "relinked_users": relinked_users,
            "total_faculties": int(total_faculties),
            "db_path": str(DB_PATH),
        }
        print(
            "Faculty dedupe done. "
            f"Deleted duplicate faculties: {deleted}, "
            f"relinked groups: {relinked_groups}, "
            f"relinked users: {relinked_users}. "
            f"Total faculties: {total_faculties}. "
            f"DB: {DB_PATH}"
        )
        return result
    finally:
        conn.close()


if __name__ == "__main__":
    dedupe()
