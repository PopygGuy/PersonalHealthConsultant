"""Centralize reference catalog into a single backend DB.

This script merges faculties/groups/norms from a legacy SQLite DB
(`./phc.db` in project root) into the canonical backend DB
(`./backend/phc.db`), keeping backend DB as the single source of truth.

Usage:
  python backend/scripts/centralize_db.py
"""

from __future__ import annotations

import sqlite3
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
BACKEND_DB = PROJECT_ROOT / "backend" / "phc.db"
LEGACY_DB = PROJECT_ROOT / "phc.db"


def _fetch_all(conn: sqlite3.Connection, query: str) -> list[sqlite3.Row]:
    conn.row_factory = sqlite3.Row
    return conn.execute(query).fetchall()


def centralize() -> None:
    if not BACKEND_DB.exists():
        raise FileNotFoundError(f"Backend DB not found: {BACKEND_DB}")

    if not LEGACY_DB.exists():
        print(f"Legacy DB not found, nothing to merge: {LEGACY_DB}")
        return

    src = sqlite3.connect(str(LEGACY_DB))
    dst = sqlite3.connect(str(BACKEND_DB))
    dst.execute("PRAGMA foreign_keys=ON")

    try:
        src_faculties = _fetch_all(src, "SELECT id, name FROM faculties")
        src_groups = _fetch_all(src, "SELECT id, name, faculty_id FROM groups")
        src_norms = _fetch_all(src, "SELECT id, name FROM norms")

        dst_faculties = _fetch_all(dst, "SELECT id, name FROM faculties")
        dst_groups = _fetch_all(dst, "SELECT id, name, faculty_id FROM groups")
        dst_norms = _fetch_all(dst, "SELECT id, name FROM norms")

        dst_faculty_by_name = {r["name"]: r["id"] for r in dst_faculties}
        dst_group_by_name = {r["name"]: (r["id"], r["faculty_id"]) for r in dst_groups}
        dst_norm_names = {r["name"] for r in dst_norms}
        src_faculty_name_by_id = {r["id"]: r["name"] for r in src_faculties}

        added_faculties = 0
        added_groups = 0
        relinked_groups = 0
        added_norms = 0

        # Faculties
        for row in src_faculties:
            fid = row["id"]
            name = row["name"]
            if not name:
                continue
            if name in dst_faculty_by_name:
                continue
            dst.execute(
                "INSERT INTO faculties(id, name) VALUES(?, ?)",
                (fid, name),
            )
            dst_faculty_by_name[name] = fid
            added_faculties += 1

        # Groups (unique by name in current schema)
        for row in src_groups:
            gid = row["id"]
            gname = row["name"]
            src_faculty_id = row["faculty_id"]
            if not gname:
                continue

            src_faculty_name = src_faculty_name_by_id.get(src_faculty_id)
            dst_faculty_id = dst_faculty_by_name.get(src_faculty_name) if src_faculty_name else None

            existing = dst_group_by_name.get(gname)
            if existing is None:
                dst.execute(
                    "INSERT INTO groups(id, name, faculty_id) VALUES(?, ?, ?)",
                    (gid, gname, dst_faculty_id),
                )
                dst_group_by_name[gname] = (gid, dst_faculty_id)
                added_groups += 1
                continue

            existing_id, existing_faculty_id = existing
            if existing_faculty_id != dst_faculty_id and dst_faculty_id is not None:
                dst.execute(
                    "UPDATE groups SET faculty_id = ? WHERE id = ?",
                    (dst_faculty_id, existing_id),
                )
                dst_group_by_name[gname] = (existing_id, dst_faculty_id)
                relinked_groups += 1

        # Norms
        for row in src_norms:
            nid = row["id"]
            name = row["name"]
            if not name or name in dst_norm_names:
                continue
            dst.execute(
                "INSERT INTO norms(id, name) VALUES(?, ?)",
                (nid, name),
            )
            dst_norm_names.add(name)
            added_norms += 1

        dst.commit()

        total_faculties = dst.execute("SELECT COUNT(*) FROM faculties").fetchone()[0]
        total_groups = dst.execute("SELECT COUNT(*) FROM groups").fetchone()[0]
        total_norms = dst.execute("SELECT COUNT(*) FROM norms").fetchone()[0]

        print(
            "Centralization done. "
            f"Added faculties: {added_faculties}, "
            f"added groups: {added_groups}, "
            f"relinked groups: {relinked_groups}, "
            f"added norms: {added_norms}. "
            f"Totals -> faculties: {total_faculties}, groups: {total_groups}, norms: {total_norms}"
        )
        print(f"Canonical DB: {BACKEND_DB}")
    finally:
        src.close()
        dst.close()


if __name__ == "__main__":
    centralize()
