#!/usr/bin/env python3
"""Generates the user guide (docs/user-guide/QLTTTA_User_Guide.docx), written in Vietnamese.

Usage:
    python3 docs/user-guide/build_user_guide.py

The content lives in chapters/ (one file per group of chapters). It reuses the report template and library
(docs/report/template, docs/report/report_lib.py) and the screenshots of tools/qlttta_screenshots
(docs/report/images/screens). Menu entries per role, demo accounts and the version are read from the source code.
Parts not written yet are g.placeholder(...) calls (yellow boxes, listed in appendix B); Windows screenshots taken
by hand go to images/windows/ and replace their placeholder on the next run.
Export the PDF on macOS: ./docs/report/tools/export_pdf.sh docs/user-guide/QLTTTA_User_Guide.docx
Requires: pip install python-docx
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from chapters import chapter1_3, chapter4_5, chapter6, front_matter  # noqa: E402
from guide_lib import REPORT_DIR, Guide  # noqa: E402

OUTPUT = HERE / "QLTTTA_User_Guide.docx"


def main() -> None:
    g = Guide(REPORT_DIR / "template" / "uit_report_template.docx")
    front_matter.cover_page(g)
    front_matter.document_info(g)
    front_matter.table_of_contents(g)
    chapter1_3.chapter1(g)
    chapter1_3.chapter2(g)
    chapter1_3.chapter3(g)
    chapter4_5.chapter4(g)
    chapter4_5.chapter5(g)
    chapter6.chapter6(g)
    chapter6.appendix_commands(g)
    chapter6.appendix_placeholders(g)
    front_matter.fill_status(g)
    g.enable_update_fields_on_open()
    g.save(OUTPUT)
    print(f"Created {OUTPUT.relative_to(HERE.parent.parent)} ({len(g.placeholders)} placeholders left)")


if __name__ == "__main__":
    main()
