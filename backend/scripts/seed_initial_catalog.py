"""Seed legacy faculties, groups and norms into current database.

Usage:
  python backend/scripts/seed_initial_catalog.py

Note:
  Uses DATABASE_URL from environment if provided. Otherwise uses app default.
"""

from pathlib import Path
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from backend.app.database import Base, SessionLocal, engine
from backend.app import models


LEGACY_FACULTY_GROUPS = {
    "Финансово-экономический факультет": [
        "38.05.01 Экономическая безопасность",
        "38.05.02 Таможенное дело",
        "38.03.01 Экономика",
        "38.03.02 Менеджмент",
        "38.03.04 Государственное и муниципальное управление",
        "38.03.05 Бизнес-информатика",
        "43.03.01 Сервис",
    ],
    "Юридический факультет": [
        "40.03.01 Юриспруденция",
    ],
    "Факультет истории и международных отношений": [
        "46.03.01 История",
        "41.03.05 Международные отношения",
        "48.03.01 Теология",
        "44.03.05 ПО (История. Обществознание)",
        "44.03.01 ПО (История)",
    ],
    "Факультет педагогики и психологии": [
        "37.03.01 Психология",
        "39.03.01 Социология",
        "39.03.02 Социальная работа",
        "44.03.01 ПО (Начальное образование)",
        "44.03.01 ПО (Дошкольное образование)",
        "44.03.02 Психолого-педагогическое образование",
        "44.03.03 Специальное (дефектологическое) образование",
    ],
    "Факультет технологии и дизайна": [
        "44.03.05 ПО (Технология. БЖД)",
        "44.03.01 ПО (Технология)",
        "20.03.01 Техносферная безопасность",
        "44.03.04 Профессиональное обучение",
    ],
    "Факультет физической культуры": [
        "44.03.05 ПО (Физкультура. БЖД)",
        "44.03.01 ПО (Физическая культура)",
        "49.03.01 Физическая культура",
        "49.03.02 Физкультура для лиц с отклонениями",
    ],
    "Филологический факультет": [
        "42.03.02 Журналистика",
        "42.03.01 Реклама и связи с общественностью",
        "44.03.05 ПО (Русский язык. Литература)",
    ],
    "Факультет иностранных языков": [
        "45.03.02 Лингвистика",
        "44.03.05 ПО (Иностранный язык)",
    ],
    "Физико-математический факультет": [
        "01.03.02 Прикладная математика и информатика",
        "02.03.02 Фундаментальная информатика и ИТ",
        "03.03.02 Физика",
        "44.03.05 ПО (Математика. Информатика)",
        "44.03.05 ПО (Физика. Информатика)",
        "44.03.01 ПО (Информатика)",
    ],
    "Естественно-географический факультет": [
        "06.03.01 Биология",
        "05.03.06 Экология и природопользование",
        "05.03.02 География",
        "04.03.01 Химия",
        "21.03.02 Землеустройство и кадастры",
        "19.03.01 Биотехнология",
        "44.03.05 ПО (Биология. Химия)",
        "44.03.05 ПО (География. Экология)",
    ],
}

LEGACY_NORMS = [
    "Бег 30м",
    "Бег 60м",
    "Бег 100м",
    "Челночный бег 3x10м",
    "Бег 1000м",
    "Бег 2000м",
    "Бег 3000м",
    "Подтягивание на высокой перекладине",
    "Подтягивание на низкой перекладине",
    "Сгибание и разгибание рук (отжимания)",
    "Рывок гири 16кг",
    "Наклон вперед (гибкость)",
    "Поднимание туловища (пресс за 1 мин)",
    "Прыжок в длину с места",
    "Метание спортивного снаряда",
    "Плавание 50м",
    "Бег на лыжах 3км/5км",
    "Стрельба из пневматической винтовки",
]


def seed_catalog() -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    added_faculties = 0
    added_groups = 0
    added_norms = 0
    linked_groups_to_new_faculty = 0

    try:
        faculty_by_name = {f.name: f for f in db.query(models.Faculty).all()}
        group_by_name = {g.name: g for g in db.query(models.Group).all()}
        norm_names = {n.name for n in db.query(models.Norm).all()}

        for faculty_name, groups in LEGACY_FACULTY_GROUPS.items():
            faculty = faculty_by_name.get(faculty_name)
            if faculty is None:
                faculty = models.Faculty(name=faculty_name)
                db.add(faculty)
                db.flush()
                faculty_by_name[faculty_name] = faculty
                added_faculties += 1

            for group_name in groups:
                existing = group_by_name.get(group_name)
                if existing is None:
                    group = models.Group(name=group_name, faculty_id=faculty.id)
                    db.add(group)
                    db.flush()
                    group_by_name[group_name] = group
                    added_groups += 1
                elif existing.faculty_id != faculty.id:
                    # Keep legacy unique-by-name model, but at least relink when mismatched.
                    existing.faculty_id = faculty.id
                    linked_groups_to_new_faculty += 1

        for norm_name in LEGACY_NORMS:
            if norm_name not in norm_names:
                db.add(models.Norm(name=norm_name))
                norm_names.add(norm_name)
                added_norms += 1

        db.commit()

        total_faculties = db.query(models.Faculty).count()
        total_groups = db.query(models.Group).count()
        total_norms = db.query(models.Norm).count()

        print(
            "Seed done. "
            f"Added faculties: {added_faculties}, "
            f"added groups: {added_groups}, "
            f"relinked groups: {linked_groups_to_new_faculty}, "
            f"added norms: {added_norms}. "
            f"Totals -> faculties: {total_faculties}, groups: {total_groups}, norms: {total_norms}"
        )
    finally:
        db.close()


if __name__ == "__main__":
    seed_catalog()
