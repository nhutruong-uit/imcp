---
paths:
  - "src/**"
  - "tools/**"
  - "CMakeLists.txt"
---
# C++ / Qt rules (src/, tools/)

Complements the "C++ / Qt" section of `CLAUDE.md` and the cookbook in `docs/ARCHITECTURE.md` section 4.

## Layout of a module (reference: Students) - all 7 parts, in the right folders
| Layer | File | Notes |
|---|---|---|
| domain | `src/domain/entities/Enrollment.{h,cpp}` | data struct + `validate()` returning a `QStringList` of errors |
| application | `src/application/ports/IEnrollmentRepository.h` | pure virtual interface returning `Result<T>`/`VoidResult` |
| application | `src/application/services/EnrollmentService.{h,cpp}` | use case: check the rules, then call the port |
| infrastructure | `src/infrastructure/repositories/SqlEnrollmentRepository.{h,cpp}` | **the only place with SQL**, calls `usp_` |
| presentation | `src/presentation/enrollments/EnrollmentPage.{h,cpp}` (+ `.ui` for a form) | never includes `infrastructure/` |
| app | `AppContainer` + `AppServices` | wires repository → service → page |
| permissions | `Feature::...` in `Permissions.cpp`, label/icon in `Labels::feature`, page in `MainWindow::pageFor` | role-based menu |
Add new files to the `CMakeLists.txt` of the right layer. Read-only lists need no page: see "Read-only list screens"
in `docs/ARCHITECTURE.md`.

## Naming (English)
- Classes/structs PascalCase (`EnrollmentService`); functions and variables camelCase (`add`, `filter`).
- Members prefixed with `m_` (`m_repository`); enum values PascalCase (`Feature::OutstandingTuition`).
- Repository functions: `search`, `findById`, `add`, `update`, `remove`; services: `search`, `details`, `add`,
  `update`, `remove`.
- Database names appear only inside SQL strings; C++ names follow the database names (`StudentId` → `id`,
  `BranchId` → `branchId`). Stored database values are English constants in the domain
  (e.g. `StudentValues::statuses()`), never display text.
- `objectName` of widgets the tests look up: camelCase English (`searchEdit`, `addButton`, `studentTable`); labels that
  tests check use `setProperty("testId", "...")`. PascalCase object names (`PageTitle`, `ErrorText`) are for styling
  (Theme/QSS).

## Code patterns
- Errors go through `Result<T>`/`VoidResult`, never exceptions across layers:
  `if (!q.exec()) return Result<QString>::failure(errorOf(q));`
- Procedures with OUTPUT: batch `SET NOCOUNT ON; DECLARE @x ...; EXEC ... @Out = @x OUTPUT; SELECT @x;`,
  `?` parameters + `addBindValue`, NULL via `SqlHelpers::stringOrNull`. Never concatenate values into SQL.
- Money/dates: `Format::money`, `Format::date` (they follow the UI language through the default `QLocale`).
- Dialogs: `UiHelpers::showError`, `UiHelpers::confirm`; buttons: `UiHelpers::primaryButton/secondaryButton`.
- Colors and fonts only in `Theme`/the style sheet - no hard-coded colors in pages (charts excepted).
- Permissions are **not** only a UI matter: hiding a button is UX, the real check is the database (GRANT).

## Multi-language UI (i18n)
- Every user-visible string: English in `tr("...")` (QObject classes) or a `Q_DECLARE_TR_FUNCTIONS` helper
  (non-QObject classes and namespaces, e.g. `LabelsText::tr`). Never build sentences by concatenating translated
  pieces; use placeholders: `tr("Delete student %1 - %2?").arg(id, name)`.
- Never cache translated text in a `static`: store the source with `QT_TRANSLATE_NOOP` and translate on use
  (see `SqlErrorMapper::constraintMessage`, `Columns`, `DbValues`, `DbMessages`).
- Codes → text in the presentation layer only: roles/menu → `Labels`, column titles/formats → `Columns`
  (key = column name of the view), stored database values → `DbValues::label`/`tone` (combo boxes show the label
  and keep the stored value as item data). Database business messages are translated by `DbMessages`
  (infrastructure, called by `SqlErrorMapper`).
- **No logic on displayed text**: never compare, parse or build identifiers (column detection, colors, file names)
  from translated text; use codes, column keys and stored values.
- After adding/changing strings: `cmake --build --preset macos-debug --target update_translations`, translate the new
  entries in `resources/translations/qlttta_vi.ts` (Qt Linguist or a text editor), and run `tst_i18n`.
- Switching language rebuilds the window (`I18n::switchTo` + `languageChangeRequested`); do not add per-widget
  `retranslateUi` code.

## Format and includes
- Format with `.clang-format` (LLVM, 4 spaces, 110 columns). Format only what you changed: `git clang-format`
  (or `git clang-format --staged`); `clang-format -i` only for new files.
- Include order: the file's own header → project headers (`"domain/..."`, `"application/..."`) → Qt (`<QString>`) → STL.
- C++17, Qt ≥ 6.7; include everything GCC/MinGW needs (Windows CI) - do not rely on Clang's indirect includes.
