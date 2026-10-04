"""Building blocks of the user guide on top of the report library (docs/report/report_lib.py).

Adds what a how-to document needs and the report does not: placeholders for the parts still to be written
(yellow boxes, counted so the cover shows how many are left), figures that fall back to a placeholder while the
image file does not exist yet (Windows screenshots taken with tools/capture_window.ps1 or
tools/capture_installer.ps1), and step lists.
"""
from __future__ import annotations

import sys
from pathlib import Path

from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.shared import Pt

GUIDE_DIR = Path(__file__).resolve().parent
REPORT_DIR = GUIDE_DIR.parent / "report"
sys.path.insert(0, str(REPORT_DIR))

from report_lib import (PAGE_WIDTH_TWIPS, Report, _para_format, _set_cell_borders,  # noqa: E402
                        _set_cell_margins, _set_cell_shading, _set_cell_width)

# Text searched for in Word (Ctrl+F) and in the content (grep) to find what is still missing
PLACEHOLDER_TAG = "CẦN BỔ SUNG"


class Guide(Report):
    def __init__(self, template: Path):
        super().__init__(template)
        self.placeholders: list[str] = []

    def _box(self, text: str, fill: str, border: str):
        t = self.doc.add_table(rows=1, cols=1)
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        c = t.cell(0, 0)
        _set_cell_shading(c, fill)
        _set_cell_borders(c, border, sz="8")
        _set_cell_margins(c, 80, 140, 80, 140)
        _set_cell_width(c, PAGE_WIDTH_TWIPS)
        for i, line in enumerate(text.split("\n")):
            p = c.paragraphs[0] if i == 0 else c.add_paragraph()
            _para_format(p, after=40, first_line=0, align="left")
            self._inline(p, line, size=11.5)
        self.doc.add_paragraph().paragraph_format.space_after = Pt(2)

    def placeholder(self, text: str, platform: str = "Windows", listed: bool = True):
        """A part that still has to be written (on the platform named): yellow box, listed in the appendix.
        listed=False for the sample box of the conventions section."""
        if listed:
            self.placeholders.append((self._section_number(), platform, text.splitlines()[0]))
        self._box(f"**[{PLACEHOLDER_TAG} - {platform}]** {text}", "FFF4CE", "E0B000")

    def _section_number(self) -> str:
        """Number of the last heading written (e.g. "2.3.1"), for the list of placeholders."""
        for p in reversed(self.doc.paragraphs):
            if p.style.name.startswith("Heading") and p.text:
                return p.text.split(" ")[0].rstrip(".") if p.text[0].isdigit() else p.text
        return ""

    def tip(self, text: str):
        """Practical tip (green box)."""
        self._box(f"**Mẹo:** {text}", "ECFDF5", "86EFAC")

    def warning(self, text: str):
        """Something that can go wrong or lose data (red box)."""
        self._box(f"**Lưu ý:** {text}", "FEF2F2", "FCA5A5")

    def steps(self, items):
        """Numbered steps (Bước 1, Bước 2...)."""
        for i, it in enumerate(items, 1):
            p = self.doc.add_paragraph()
            # left-aligned: justified hanging-indent lines with URLs/menu paths get very wide gaps
            _para_format(p, after=60, first_line=0, align="left")
            p.paragraph_format.left_indent = Pt(42)
            p.paragraph_format.first_line_indent = Pt(-42)
            self._inline(p, f"**Bước {i}.** " + it)

    def figure_or_placeholder(self, path: Path, caption: str, todo: str, platform: str = "Windows",
                              width_cm: float = 15.5):
        """The figure when the image exists; otherwise a placeholder naming the file to add."""
        if path.exists():
            self.figure(path, caption, width_cm=width_cm)
            return
        rel = path.relative_to(GUIDE_DIR.parent.parent).as_posix()
        how = (f"Mở cửa sổ đó, chạy `.\\docs\\user-guide\\tools\\capture_window.ps1 -Name {path.stem}` và bấm vào "
               f"cửa sổ trong 5 giây (ảnh lưu vào `{rel}`)" if platform == "Windows" else f"Lưu ảnh vào `{rel}`")
        self.placeholder(f"Ảnh: {todo}\n{how}, rồi chạy lại `build_user_guide.py` (chú thích: \"{caption}\").",
                         platform)

    def set_header_text(self, text: str):
        for section in self.doc.sections:
            for p in section.header.paragraphs:
                if p.runs:
                    p.runs[0].text = text
                    for r in p.runs[1:]:
                        r.text = ""

    def remove_template_pages(self, first_paragraph_text: str):
        """Removes everything of the template from the paragraph with this text on (checklist, comments page)."""
        body = self.body
        start = next(p._p for p in self.doc.paragraphs if p.text.strip() == first_paragraph_text)
        children = list(body)
        for el in children[children.index(start):]:
            if el.tag.endswith("}sectPr"):
                break
            body.remove(el)
