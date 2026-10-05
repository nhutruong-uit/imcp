#!/usr/bin/env python3
"""Generates the IE103 project report (docs/report/IE103_Group1_Report.docx).

Usage:
    python3 docs/report/build_report.py                 # the committed report: student IDs masked
    python3 docs/report/build_report.py --submission    # the copy for the lecturer: real student IDs

The content lives in content/ (one file per chapter). SQL code is extracted from database/*.sql; the data
dictionary and the query/test results come from data/*.json|txt (exported from the real database); screenshots
come from images/screens (tools/qlttta_screenshots). The generated file has the updateFields flag so Word refreshes
the table of contents, the lists of figures/tables and the page numbers when it opens it (Word asks "update the
fields?" -> "Yes"). On macOS run tools/export_pdf.sh next: it exports the PDF and replaces the docx with the version
Word updated (no flag left, so opening it does not ask again).
The repository may be public, so the committed report shows only the last 2 digits of each student ID.
--submission reads the real IDs from student_ids.local.json (not committed) and writes
IE103_Group1_Report_submission.docx (not committed either; export its PDF the same way).
Requires: pip install python-docx
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from content import chapter1_2, chapter3, chapter4, chapter5, chapter6_8, front_matter  # noqa: E402
from content.common import use_real_student_ids  # noqa: E402
from report_lib import Report  # noqa: E402

OUTPUT = HERE / "IE103_Group1_Report.docx"
SUBMISSION_OUTPUT = HERE / "IE103_Group1_Report_submission.docx"


def main() -> None:
    submission = "--submission" in sys.argv[1:]
    if submission:
        use_real_student_ids()
    output = SUBMISSION_OUTPUT if submission else OUTPUT
    r = Report(HERE / "template" / "uit_report_template.docx")
    front_matter.cover_page(r)
    front_matter.checklist(r)
    front_matter.assignments(r)
    front_matter.table_of_contents(r)
    chapter1_2.chapter1(r)
    chapter1_2.chapter2(r)
    chapter3.chapter3(r)
    chapter4.chapter4(r)
    chapter5.chapter5(r)
    chapter6_8.chapter6(r)
    chapter6_8.chapter7(r)
    chapter6_8.chapter8(r)
    chapter6_8.references(r)
    chapter6_8.appendix(r)
    r.enable_update_fields_on_open()
    r.save(output)
    print(f"Created {output.relative_to(HERE.parent.parent)}")


if __name__ == "__main__":
    main()
