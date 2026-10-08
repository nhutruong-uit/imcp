# Demo video

`QLTTTA_Demo_vi.mp4` shows the application at work, from the login screen to the four roles (manager, academic staff,
accountant, teacher). Nobody operates it: a program signs in with the demo accounts, moves the pointer, types, clicks
and fills in forms on the **real application against the real SQL Server database**, and writes a caption for each
step. Use it to see the project without installing anything, to prepare the oral defense, or to check that a change
did not break a flow.

The video is Vietnamese (screens and captions), like the report and the user guide. It has a chapter list (QuickTime,
VLC and most players show it). English: `./scripts/record_demo.sh --lang en --out build/demo_en.mp4` (not committed).

## What the video shows

| Chapter | Account | What happens |
|---|---|---|
| Sign in | - | Four roles that are real SQL Server users, the server settings of the login screen, a wrong password refused by SQL Server |
| Manager | `ql_quan` | Dashboard and its branch filter, student search, profile, add (the guardian rule of a student under 18) and delete, courses with their XML syllabus, teachers, branches, promotions, accounts, backup |
| Academic staff | `gvu_lan` | No revenue (the database does not return it), placement tests, classes (students, weekly timetable), a new enrollment, put on hold and resume, the weekly timetable, grade book, learning results |
| Accountant | `kt_minh` | Read-only students, collecting a payment and printing the receipt, cancelling a receipt, outstanding tuition with a print preview grouped by class, revenue, payroll |
| Teacher | `gv_john` | Only his own classes, schedule, grades and pay; taking attendance |
| Two languages | `gv_john` | The whole screen rebuilt in English and back |

## Watching it

- On the project site: <https://nhutruong-uit.github.io/imcp/#demo> (the player is in the Product section).
- On GitHub: the file page plays it in the browser.
- From a clone: open `docs/demo/QLTTTA_Demo_vi.mp4`.

The site plays the file of `develop`: `pages.yml` publishes `docs/demo/*.mp4` when it changes there, so a new
recording shows online after its pull request is merged.

## How it is made

```
scripts/record_demo       builds the tool, optionally reloads the seed data, runs the tool
tools/demo_video_tool.cpp reads the settings and starts the pieces below
tools/demo/Scenario.cpp   the story: one function per chapter, written as what a person does
tools/demo/Director.*     the person: glides the pointer, clicks, types letter by letter, picks from a combo box,
                          and plays the part of main.cpp (login -> main window -> log out -> login)
tools/demo/Recorder.*     the camera: photographs the application's windows 15 times a second, adds the pointer, the
                          captions and the title cards, and pipes the pictures to ffmpeg
docs/demo/captions.tsv    every word of the video, in English and Vietnamese, one line per id
```
- **Nothing is captured from the screen.** `Recorder` asks Qt for a picture of each window (`QWidget::grab`) and puts
  them together, so the tool needs no Screen Recording permission, runs with `QT_QPA_PLATFORM=offscreen` (no window
  appears while it records), and a second run gives the same video. The price: a window frame (title bar) is not drawn.
- The application code is the same as the real one (`AppContainer`, `MainWindow`, the pages), signed in as real SQL
  Server users, so every number on the screen comes from the database. A clash of the story with the application (a
  missing button, a page that does not open) stops the run with a clear message instead of recording a wrong video.
- The script runs in its own thread and calls the GUI thread for every action; a click that opens a dialog does not
  return until the dialog closes, so it is queued and the story goes on inside the dialog (`Director.h` explains).
- A caption stays on screen long enough to be read, and the story waits for it before it changes page.

## Recording it again

Needs `ffmpeg` (`brew install ffmpeg`, Windows: `winget install Gyan.FFmpeg`) and a database with the seed data:

```bash
SQL_PASSWORD="$(docker exec imcp-mssql printenv MSSQL_SA_PASSWORD)" ./scripts/record_demo.sh --init-db --docker imcp-mssql
```
```powershell
.\scripts\record_demo.ps1 -InitDb
```
It takes about as long as the video. `--init-db` re-creates the QLTTTA database (the demo adds a student and a
receipt and changes an attendance mark, and the dates of the seed data are relative to the day it was loaded, so a
fresh load gives the same video); never run it against a database somebody is using - SQL Server in a private Docker
container is the safe choice (see `docs/SETUP.md`). Options: `--lang`, `--out`, `--chapters`; the environment
variables (frame rate, size, quality) are listed at the top of `tools/demo_video_tool.cpp`.

If the run stops, the pictures so far are kept as `<video>.failed.mp4` (ignored by git) to see where it stopped; the
committed video is only replaced by a complete run.

## Changing the story

1. Add or change a step in `tools/demo/Scenario.cpp`. A step is a call such as
   `d.click(d.find<QPushButton>("addButton"))`, `d.type(edit, "text")`, `d.openPage(Feature::Students)`,
   `d.say("students.add")`. The widgets are found by the `objectName` that the end-to-end tests also use.
2. Write what the viewer reads in `docs/demo/captions.tsv`: an id, an English text and a Vietnamese text, separated by
   TAB characters. Short sentences are best (a caption stays about 18 characters per second of reading time).
3. Try it alone and fast: `./scripts/record_demo.sh --chapters manager --out build/try.mp4`, then look at the
   pictures (`ffmpeg -i build/try.mp4 -vf fps=1/3,scale=640:-1,tile=3x4 build/sheet.png`).
4. Record the whole video and commit it.

## Size and git

The video is a binary file: every committed version stays in the history forever (about 10 MB each). Record it again
when a screen it shows changes noticeably or before a release, not for every small change. GitHub warns above 50 MB;
`QLTTTA_DEMO_CRF` (higher = smaller) and `QLTTTA_DEMO_FPS` keep it small, and the script warns above 15 MB.
