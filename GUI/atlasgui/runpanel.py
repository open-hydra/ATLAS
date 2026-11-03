"""The Run stage: GPB, BCB and ICB run on the case, their log and what they wrote.

* **Tools** -- the tools of the run, in the order they run, each with what it
  builds from the deck (or why it has nothing to build), its state and, once
  it has run, its time, its files and the errors and warnings it printed;
* **Before the run** -- what the run will do first and what would stop it
  (:func:`atlasgui.runner.preflight`), and the hand-off of GPB's phase tables;
* **Log** -- the output of every tool as it runs, its errors and warnings
  coloured, with what the run does besides (``›``);
* **fromATLAStoSolver/** -- the files there, those of the last run first.

When a tool ends, its errors and warnings are read from its output
(:func:`atlasgui.runlog.messages`), each on the section it names: Review lists
them with the GUI's own checks, and shows each one's line in the log.

The run itself is a :class:`atlasgui.runner.RunSession`; the shell saves the
INI before it starts, and its header has Run and Stop for every stage.
"""

from __future__ import annotations

import datetime
import os
import time

from PyQt6.QtCore import Qt, QTimer, QUrl, pyqtSignal
from PyQt6.QtGui import (QBrush, QColor, QDesktopServices, QFont, QKeySequence,
                         QSyntaxHighlighter, QTextCharFormat, QTextCursor)
from PyQt6.QtWidgets import (
    QCheckBox, QFileDialog, QFrame, QHBoxLayout, QHeaderView, QLabel, QMessageBox,
    QPlainTextEdit, QProgressBar, QSplitter, QTreeWidget, QTreeWidgetItem, QVBoxLayout,
    QWidget,
)

from . import icons, preferences, runlog, runner
from .widgets import Card, clear_layout

LEVEL_COLORS = {"error": "danger", "warning": "warning", "action": "accent",
                "info": "muted", "ok": "success"}
STATE_TEXT = {"waiting": ("ready", "muted"), "running": ("running…", "accent"),
              "done": ("done", "success"), "failed": ("failed", "danger"),
              "stopped": ("stopped", "warning"), "skipped": ("skipped", "muted"),
              "off": ("not selected", "faint"), "idle": ("nothing to build", "faint")}
# the mark a log line starts with, by what it is
MARKS = {"start": "▶ ", "done": "✔ ", "failed": "✖ ", "stopped": "■ ", "gui": "› "}


class LogHighlighter(QSyntaxHighlighter):
    """The colours of the log: a tool starting and ending, the run's own
    lines, and the errors and warnings the tools print."""

    def __init__(self, document, tokens):
        super().__init__(document)
        self.set_theme(tokens)

    def set_theme(self, t):
        def fmt(colour, bold=False, italic=False):
            f = QTextCharFormat()
            f.setForeground(QBrush(QColor(colour)))
            if bold:
                f.setFontWeight(QFont.Weight.Bold)
            f.setFontItalic(italic)
            return f

        self._marks = {MARKS["start"]: fmt(t["syn_section"], bold=True),
                       MARKS["done"]: fmt(t["success_text"], bold=True),
                       MARKS["failed"]: fmt(t["danger_text"], bold=True),
                       MARKS["stopped"]: fmt(t["warning_text"], bold=True),
                       MARKS["gui"]: fmt(t["syn_comment"], italic=True)}
        self._levels = {"error": fmt(t["danger_text"]), "warning": fmt(t["warning_text"])}
        self.rehighlight()

    def highlightBlock(self, text):
        level = runner.line_level(text)
        for mark, style in self._marks.items():
            if text.startswith(mark):
                gui = mark == MARKS["gui"]
                self.setFormat(0, len(text), self._levels[level] if gui and level else style)
                return
        if level:
            self.setFormat(0, len(text), self._levels[level])


class ToolRow(QFrame):
    """One tool of the run: whether it runs, what it builds, how it went."""

    def __init__(self, panel, tool):
        super().__init__()
        self.setObjectName("Tile")
        self.panel = panel
        self.tool = tool
        kit = panel.kit
        lay = QVBoxLayout(self)
        lay.setContentsMargins(12, 9, 12, 9)
        lay.setSpacing(3)
        head = QHBoxLayout()
        head.setSpacing(8)
        self.check = QCheckBox(tool.name)
        self.check.setToolTip(f"Run {tool.name}: {tool.builds}")
        bold = QFont(self.check.font())
        bold.setWeight(QFont.Weight.Bold)
        self.check.setFont(bold)
        self.check.toggled.connect(lambda on: panel.select_tool(tool.name, on))
        head.addWidget(self.check)
        head.addWidget(kit.icon_label(panel.shell_icon(tool.stage), "muted", 15))
        label = QLabel(tool.label)
        label.setProperty("role", "muted")
        head.addWidget(label)
        head.addStretch(1)
        self.dot = QLabel()
        head.addWidget(self.dot)
        self.state = QLabel()
        self.state.setProperty("role", "value")
        head.addWidget(self.state)
        lay.addLayout(head)
        self.note = kit.hint("")
        lay.addWidget(self.note)
        foot = QHBoxLayout()
        foot.setSpacing(6)
        self.result = kit.hint("")
        foot.addWidget(self.result)
        foot.addStretch(1)
        self.log_button = kit.button("Log", lambda: panel.show_tool_log(tool.name),
                                     "terminal", "ghost",
                                     tip=f"Show where {tool.name} starts in the log")
        self.error_button = kit.button("First error", lambda: panel.show_tool_log(tool.name, True),
                                       "alert", "ghost",
                                       tip=f"Show the first error {tool.name} printed")
        foot.addWidget(self.error_button)
        # what the tool wrote, drawn in its stage
        self.field_button = {
            "GPB": lambda: kit.button(
                "Tables", lambda: panel.shell.show_tables(), "chart", "ghost",
                tip="The tables GPB wrote, drawn (Phases stage)"),
            "BCB": lambda: kit.button(
                "Boundaries", lambda: panel.shell.show_written_bcs(), "boundary", "ghost",
                tip="The BC of every boundary cell as BCB wrote it (Boundaries stage)"),
            "ICB": lambda: kit.button(
                "Field", lambda: panel.shell.show_initial_field(), "initial", "ghost",
                tip="The field ICB wrote, on the cells of the mesh (Initial stage)"),
        }.get(tool.name, lambda: None)()
        if self.field_button is not None:
            foot.addWidget(self.field_button)
        foot.addWidget(self.log_button)
        lay.addLayout(foot)
        self.state_key = "waiting"

    def update_state(self, enabled, note, selected, result):
        """*result*: the tool's :class:`~atlasgui.runner.ToolResult` of the
        last run, or None."""
        # A run keeps the tools it started with: the boxes choose the next one.
        self.check.blockSignals(True)
        self.check.setEnabled(enabled)
        self.check.setChecked(enabled and selected)
        self.check.blockSignals(False)
        self.note.setText(note)
        if result is not None and (result.status != "waiting" or self.panel.running()):
            key = result.status
        elif not enabled:
            key = "idle"
        elif not selected:
            key = "off"
        else:
            key = "waiting"
        self.state_key = key
        text, token = STATE_TEXT[key]
        if key == "waiting" and self.panel.running() and result is not None:
            text = "waiting"
        if result is not None and result.status in ("done", "failed", "stopped"):
            text = f"{text} · {result.seconds:.1f} s"
        self.state.setText(text)
        self.dot.setPixmap(icons.dot_pixmap(self.panel.kit.color(token), self.panel.kit.px(10)))
        parts = []
        if result is not None and result.status in ("done", "failed", "stopped"):
            files = len(result.files)
            parts.append(f"{files} file{'s' * (files != 1)} written" if files
                         else "no file written")
            for count, word in ((result.errors, "error"), (result.warnings, "warning")):
                if count:
                    parts.append(f"{count} {word}{'s' * (count != 1)}")
        self.result.setText(" · ".join(parts))
        self.result.setVisible(bool(parts))
        ran = result is not None and result.status not in ("waiting", "skipped")
        self.log_button.setVisible(ran)
        self.error_button.setVisible(ran and result.errors > 0)
        if self.field_button is not None:
            self.field_button.setVisible(result is not None and result.status == "done"
                                         and bool(result.files))


class RunPanel(QWidget):
    """The Run stage.  ``running_changed(bool)`` tells the shell a run starts
    or ends (its header swaps Run and Stop)."""

    running_changed = pyqtSignal(bool)

    def __init__(self, shell):
        super().__init__()
        self.shell = shell
        self.kit = shell.kit
        self.session = None
        self.results = {}                       # the last run's ToolResult by tool
        self.selected = {name: True for name in runner.TOOL_NAMES}
        self._anchors = {}                      # tool -> (first line, first error line)
        self._out_blocks = {}                   # tool -> the log line of each line it printed
        self.messages = {}                      # tool -> its runlog.Message of the last run
        self.run_ini = None                     # (INI path, its text, time) of the last run
        store = shell.settings
        self.handoff = str(store.value("run/hand-off", "true")).lower() != "false"
        self._build()
        self._clock = QTimer(self)
        self._clock.setInterval(1000)
        self._clock.timeout.connect(self._tick)

    def shell_icon(self, stage):
        from .mainwindow import STAGES
        return next(icon for key, _l, icon, _t in STAGES if key == stage)

    # ------------------------------------------------------------- layout
    def _build(self):
        kit = self.kit
        outer = QHBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setHandleWidth(9)
        splitter.setChildrenCollapsible(False)

        left = QWidget()
        column = QVBoxLayout(left)
        column.setContentsMargins(0, 0, 0, 0)
        column.setSpacing(10)

        tools = Card()
        tools.body.addLayout(kit.panel_header("play", "TOOLS"))
        self.rows = {}
        for tool in runner.TOOLS:
            row = ToolRow(self, tool)
            self.rows[tool.name] = row
            tools.body.addWidget(row)
        buttons = QHBoxLayout()
        buttons.setSpacing(7)
        self.run_button = kit.button("Run", self.run, "play", "primary",
                                     tip="Save the case and run the selected tools, in order")
        self.stop_button = kit.button("Stop", self.stop, "stop", "danger",
                                      tip="End the tool that runs; the others do not start")
        buttons.addWidget(self.run_button, 1)
        buttons.addWidget(self.stop_button, 1)
        tools.body.addLayout(buttons)
        self.busy = QProgressBar()
        self.busy.setTextVisible(False)
        self.busy.setRange(0, 0)
        self.busy.setVisible(False)
        tools.body.addWidget(self.busy)
        summary = QHBoxLayout()
        summary.setSpacing(6)
        self.summary = kit.hint("")
        summary.addWidget(self.summary, 1)
        self.review_button = kit.button(
            "", lambda: self.shell.set_stage("review"), "review", "ghost",
            tip="The errors and warnings the tools printed, on the sections they name")
        self.review_button.setVisible(False)
        summary.addWidget(self.review_button)
        tools.body.addLayout(summary)
        column.addWidget(tools)

        before = Card()
        self.check_badge = kit.badge("0")
        before.body.addLayout(kit.panel_header(
            "check", "BEFORE THE RUN", self.check_badge,
            trailing=[kit.button("Tools…", lambda: self.shell.open_settings("tools"), "gear",
                                 "ghost", tip="Settings → Tools: the ATLAS directory, the "
                                 "Python of GPB, the threads")]))
        # labels, not list items: a list item measured with one width and
        # painted with another (the stylesheet's padding) cuts its last line
        holder = QWidget()
        holder.setObjectName("CheckRows")
        self.check_rows = QVBoxLayout(holder)
        self.check_rows.setContentsMargins(2, 2, 2, 2)
        self.check_rows.setSpacing(8)
        before.body.addWidget(kit.scrollable(holder), 1)
        self.handoff_toggle = kit.toggle(
            "Give BCB and ICB the phase tables GPB writes", self._set_handoff,
            checked=self.handoff, compactable=False,
            tip="After GPB, copy the *phase.txt, *thermo.dat and *properties.dat it has just "
                "written into the case directory, where BCB and ICB read them")
        before.body.addWidget(self.handoff_toggle)
        column.addWidget(before, 1)
        # a short window scrolls the column: no row is squeezed over another
        splitter.addWidget(kit.scrollable(left, horizontal=True))

        right = QSplitter(Qt.Orientation.Vertical)
        right.setHandleWidth(9)
        right.setChildrenCollapsible(False)
        log = Card()
        log.body.addLayout(kit.panel_header("terminal", "LOG", trailing=[
            kit.button("Save log…", self.save_log, "save", "ghost",
                       tip="Write the log to a text file"),
            kit.button("Clear", self.clear_log, "trash", "ghost", tip="Empty the log")]))
        self.console = QPlainTextEdit()
        self.console.setReadOnly(True)
        self.console.setLineWrapMode(QPlainTextEdit.LineWrapMode.WidgetWidth)  # long errors
        self.console.setMaximumBlockCount(100000)
        keys = QKeySequence("Ctrl+R").toString(QKeySequence.SequenceFormat.NativeText)
        self.console.setPlaceholderText(
            f"The output of the tools shows here as they run: Run, or {keys} from any stage.")
        self.highlighter = LogHighlighter(self.console.document(), self.kit.theme)
        log.body.addWidget(self.console, 1)
        right.addWidget(log)

        outputs = Card()
        self.output_badge = kit.badge("0")
        outputs.body.addLayout(kit.panel_header(
            "open", "FROMATLASTOSOLVER/", self.output_badge,
            trailing=[kit.button("Open folder", self.open_output_dir, "open", "ghost",
                                 tip="Show the folder in the file manager")]))
        self.output_tree = QTreeWidget()
        self.output_tree.setColumnCount(4)
        self.output_tree.setHeaderLabels(["FILE", "WRITTEN BY", "SIZE", "MODIFIED"])
        self.output_tree.setRootIsDecorated(False)
        self.output_tree.setUniformRowHeights(True)
        header = self.output_tree.header()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        for col in (1, 2, 3):
            header.setSectionResizeMode(col, QHeaderView.ResizeMode.ResizeToContents)
        self.output_tree.itemDoubleClicked.connect(self._open_output)
        self.output_tree.setToolTip("What the tools wrote for the solver. A double click "
                                    "draws a table, the boundary file or the initial field in "
                                    "its stage, and opens any other file.")
        outputs.body.addWidget(self.output_tree, 1)
        right.addWidget(outputs)
        right.setStretchFactor(0, 3)
        right.setStretchFactor(1, 1)
        splitter.addWidget(right)
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setSizes([kit.px(440), kit.px(900)])
        outer.addWidget(splitter)

    # -------------------------------------------------------------- state
    def running(self):
        return self.session is not None and self.session.is_running()

    def tool_settings(self):
        return preferences.tool_settings(self.shell.settings)

    def _environment(self):
        """``(root, python, how, env)`` from Settings → Tools."""
        values = self.tool_settings()
        root = runner.atlas_root(values["atlas-dir"])
        python, how = runner.gpb_python(values["python"])
        return root, python, how, runner.environment(root, python, values["threads"])

    def readiness(self):
        return runner.readiness(self.shell.doc)

    def chosen(self):
        """The tools that would run: selected, and with something to build."""
        ready = self.readiness()
        return [n for n in runner.TOOL_NAMES if ready[n][0] and self.selected[n]]

    def preflight(self):
        shell = self.shell
        values = self.tool_settings()
        root = runner.atlas_root(values["atlas-dir"])
        python, how = runner.gpb_python(values["python"])
        return runner.preflight(
            shell.doc, shell.case_dir, self.chosen(), ini_path=shell.ini_path,
            dirty=shell._dirty, mesh_path=shell.bcb_panel.mesh_path, root=root,
            python=python, python_how=how, handoff=self.handoff, issues=shell._issues())

    def select_tool(self, name, on):
        self.selected[name] = on
        self.refresh()

    def _set_handoff(self, on):
        self.handoff = on
        self.shell.settings.setValue("run/hand-off", "true" if on else "false")
        self.refresh()

    # ------------------------------------------------------------ refresh
    def refresh(self):
        ready = self.readiness()
        for name, row in self.rows.items():
            enabled, note = ready[name]
            row.update_state(enabled, note, self.selected[name], self.results.get(name))
        running = self.running()
        chosen = self.chosen()
        self.run_button.setEnabled(bool(chosen))
        self.run_button.setVisible(not running)
        self.stop_button.setVisible(running)
        self.busy.setVisible(running)
        self.handoff_toggle.setVisible("GPB" in chosen and any(n in chosen for n in ("BCB", "ICB")))
        self.handoff_toggle.setEnabled(not running)
        if not running:
            self._refresh_checks()
        self.refresh_outputs()
        self._refresh_summary()

    def _refresh_checks(self):
        clear_layout(self.check_rows)
        checks = self.preflight()
        for check in checks:
            prefix = f"{check.tool}: " if check.tool else ""
            row = QHBoxLayout()
            row.setSpacing(8)
            dot = QLabel()
            dot.setPixmap(icons.dot_pixmap(self.kit.color(LEVEL_COLORS[check.level]),
                                           self.kit.px(10)))
            dot.setAlignment(Qt.AlignmentFlag.AlignTop)
            dot.setContentsMargins(0, self.kit.px(3), 0, 0)
            row.addWidget(dot)
            text = QLabel(prefix + check.text)
            text.setWordWrap(True)
            text.setToolTip(f"{check.level}: {prefix}{check.text}")
            row.addWidget(text, 1)
            self.check_rows.addLayout(row)
        self.check_rows.addStretch(1)
        blocking = sum(1 for c in checks if c.level in ("error", "warning"))
        self.check_badge.setText(str(blocking))
        self.check_badge.setToolTip(f"{blocking} error(s) and warning(s)")

    def _refresh_summary(self):
        if self.running():
            name = self.session.running
            elapsed = time.monotonic() - self.session.results[name].started
            self.summary.setText(f"{name} is running ({elapsed:.0f} s)")
        elif self.session is not None and self.session.ok is not None:
            total = sum(r.seconds for r in self.session.results.values())
            stamp = self._finished_at.strftime("%H:%M:%S")
            if self.session.ok:
                self.summary.setText(f"Last run: done in {total:.1f} s, at {stamp}")
            else:
                bad = next((r for r in self.session.results.values()
                            if r.status in ("failed", "stopped")), None)
                what = f"{bad.name} {bad.status}" if bad else "stopped"
                self.summary.setText(f"Last run: {what}, at {stamp}")
        else:
            self.summary.setText("Not run yet in this window.")
        told = self.tool_messages()
        self.review_button.setVisible(bool(told) and not self.running())
        if told:
            n = len(told)
            self.review_button.setText(f"  {n} message{'s' * (n != 1)} in Review")

    def refresh_outputs(self):
        out = os.path.join(self.shell.case_dir, runner.OUTPUT_DIR)
        files = runner.snapshot(out)
        by = {}
        if self.session is not None and os.path.abspath(self.session.out_dir) == os.path.abspath(out):
            for name, result in self.session.results.items():
                for f in result.files:
                    by[f] = name
        self.output_tree.clear()
        order = {n: i for i, n in enumerate(runner.TOOL_NAMES)}
        bold = QFont(self.output_tree.font())
        bold.setWeight(QFont.Weight.DemiBold)
        muted = QBrush(QColor(self.kit.color("muted")))
        for name in sorted(files, key=lambda f: (order.get(by.get(f), 9), f.lower())):
            mtime, size = files[name]
            stamp = datetime.datetime.fromtimestamp(mtime / 1e9)
            item = QTreeWidgetItem([name, by.get(name, "—"), _size(size),
                                    stamp.strftime("%d %b %H:%M:%S")])
            item.setData(0, Qt.ItemDataRole.UserRole, os.path.join(out, name))
            item.setIcon(0, self.kit.icon("file", "muted", 15))
            item.setTextAlignment(2, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
            if name in by:
                item.setFont(0, bold)
                item.setToolTip(0, f"written by {by[name]} in the last run")
            else:
                for col in (1, 2, 3):
                    item.setForeground(col, muted)
                item.setToolTip(0, "not written by the last run")
            self.output_tree.addTopLevelItem(item)
        self.output_badge.setText(str(len(files)))

    def restyle(self):
        self.highlighter.set_theme(self.kit.theme)
        self.refresh()

    # ---------------------------------------------------------------- run
    def run(self):
        """Save the case, check it, and run the selected tools."""
        if self.running():
            return False
        shell = self.shell
        names = self.chosen()
        if not names:
            shell.warn("Run", "No tool to run: select one that has something to build.")
            return False
        if not shell.ini_path:
            shell.save_ini()                    # where the INI goes is the case directory
            if not shell.ini_path:
                return False
        checks = self.preflight()
        errors = [c for c in checks if c.level == "error"]
        if errors:
            QMessageBox.warning(self, "Run", "The run cannot start:\n\n" + "\n".join(
                f"• {(c.tool + ': ') if c.tool else ''}{c.text}" for c in errors))
            self._refresh_checks()
            return False
        warnings = [c for c in checks if c.level == "warning"]
        if warnings:
            box = QMessageBox(QMessageBox.Icon.Warning, "Run",
                              "Before the run:\n\n" + "\n".join(
                                  f"• {(c.tool + ': ') if c.tool else ''}{c.text}"
                                  for c in warnings) + "\n\nRun anyway?",
                              parent=self)
            run = box.addButton("Run anyway", QMessageBox.ButtonRole.AcceptRole)
            box.addButton(QMessageBox.StandardButton.Cancel)
            box.exec()
            if box.clickedButton() is not run:
                return False
        if shell._dirty:
            shell.save_ini()
            if shell._dirty:
                return False                    # declined (faces without a BC), or the write failed
        root, python, _how, env = self._environment()
        plan = runner.mesh_plan(shell.case_dir, shell.bcb_panel.mesh_path)
        needs_mesh = any(n in names for n in ("BCB", "ICB"))
        link = (plan.link, shell.bcb_panel.mesh_path) if needs_mesh and plan.link else None

        if self.session is not None:
            self.session.deleteLater()
        self.session = runner.RunSession(
            shell.case_dir, runner.ini_argument(shell.ini_path, shell.case_dir), names, env,
            script=runner.launcher(root), mesh_link=link,
            handoff=self.handoff and "GPB" in names, parent=self)
        self.results = self.session.results
        self._anchors = {}
        self._out_blocks = {}
        self.messages = {}
        self.run_ini = (shell.ini_path, shell.doc.to_ini(), datetime.datetime.now())
        self.session.line.connect(self._line)
        self.session.tool_started.connect(lambda _n: self.refresh())
        self.session.tool_finished.connect(self._tool_finished)
        self.session.finished.connect(self._finished)
        if self.console.document().blockCount() > 1 or self.console.toPlainText():
            self.console.appendPlainText("")
        stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.console.appendPlainText(
            f"{MARKS['gui']}run of {', '.join(names)} in {shell.case_dir}, started {stamp}")
        self._clock.start()
        self.running_changed.emit(True)
        self.session.start()            # may end at once (a link that cannot be made)
        self.refresh()
        return True

    def stop(self):
        if self.running():
            self.session.stop()

    def stop_and_wait(self, msecs=5000):
        """Stop the run and wait for its tool to end (the window closes)."""
        if self.running():
            self.session.stop()
            self.session.wait(msecs)

    def _line(self, name, text, kind):
        if kind == "head":
            status = self.session.results[name].status if name in self.session.results else ""
            mark = MARKS.get(status, MARKS["start"]) if status != "running" else MARKS["start"]
            text = mark + text
        elif kind == "gui":
            text = MARKS["gui"] + text
        self.console.appendPlainText(text)
        line = self.console.document().blockCount() - 1
        if kind == "out":
            self._out_blocks.setdefault(name, []).append(line)
        first, error = self._anchors.get(name, (None, None))
        if kind == "head" and first is None:
            first = line
        if error is None and kind != "head" and runner.line_level(text) == "error":
            error = line
        self._anchors[name] = (first, error)

    def _tool_finished(self, name):
        result = self.session.results[name]
        if result.status in ("done", "failed", "stopped"):
            self.messages[name] = runlog.messages(name, result.lines, self.shell.doc,
                                                  failed=result.status == "failed")
        self.refresh()
        self.shell.refresh_run_state()
        if self.shell.current_stage == "review":
            self.shell.refresh_review()

    # ------------------------------------------------------- the messages
    def tool_messages(self):
        """The errors and warnings of the last run, tool by tool, while the
        case is the one it ran on."""
        if self.run_ini is None or self.run_ini[0] != self.shell.ini_path:
            return []
        return [m for name in runner.TOOL_NAMES for m in self.messages.get(name, [])]

    def messages_stale(self):
        """True when the case has changed since the run its messages are of."""
        return self.run_ini is not None and self.shell.doc.to_ini() != self.run_ini[1]

    def run_time(self):
        return self.run_ini[2] if self.run_ini else None

    def show_log_line(self, name, index):
        """Show line *index* of what tool *name* printed, in the log."""
        blocks = self._out_blocks.get(name, [])
        result = self.results.get(name)
        if index is None or result is None or not 0 <= index < len(blocks):
            return False
        block = self.console.document().findBlockByNumber(blocks[index])
        if not block.isValid() or block.text() != result.lines[index]:
            return False                        # the log was cleared or trimmed since
        self._scroll_to(block)
        return True

    def _finished(self, ok):
        self._clock.stop()
        self._finished_at = datetime.datetime.now()
        self.running_changed.emit(False)
        self.refresh()
        self.shell.run_finished(ok)

    def _tick(self):
        self._refresh_summary()
        self.shell.refresh_run_state()

    def state_text(self):
        """``(text, token)`` for the status bar, or None before any run."""
        session = self.session
        if session is None:
            return None
        if self.running():
            name = session.running
            elapsed = time.monotonic() - session.results[name].started
            return f"{name} running · {elapsed:.0f} s", "accent"
        if session.ok is None:
            return "starting…", "accent"
        if session.ok:
            total = sum(r.seconds for r in session.results.values())
            return f"run done · {total:.1f} s", "success"
        bad = next((r for r in session.results.values() if r.status in ("failed", "stopped")),
                   None)
        if bad is not None and bad.status == "failed":
            return f"{bad.name} failed", "danger"
        return "run stopped", "warning"

    # ---------------------------------------------------------------- log
    def show_tool_log(self, name, error=False):
        first, err = self._anchors.get(name, (None, None))
        line = err if error else first
        if line is None:
            return
        block = self.console.document().findBlockByNumber(line)
        if block.isValid():
            self._scroll_to(block)

    def _scroll_to(self, block):
        # from the end, the view scrolls up to the line and shows it at the top
        self.console.moveCursor(QTextCursor.MoveOperation.End)
        cursor = QTextCursor(block)
        self.console.setTextCursor(cursor)
        self.console.ensureCursorVisible()
        self.console.setFocus()

    def clear_log(self):
        self.console.clear()
        self._anchors = {}
        self._out_blocks = {}

    def save_log(self):
        start = os.path.join(self.shell.case_dir, "atlas-run.log")
        path, _ = QFileDialog.getSaveFileName(self, "Save log", start,
                                              "Logs (*.log *.txt);;All files (*)")
        if not path:
            return
        try:
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(self.console.toPlainText() + "\n")
        except OSError as exc:
            QMessageBox.critical(self, "Save log", str(exc))

    # ------------------------------------------------------------ outputs
    def open_output_dir(self):
        out = os.path.join(self.shell.case_dir, runner.OUTPUT_DIR)
        if not os.path.isdir(out):
            self.shell.warn("Open folder", f"There is no {runner.OUTPUT_DIR}/ in the case "
                            "directory yet: the tools make it.")
            return
        QDesktopServices.openUrl(QUrl.fromLocalFile(out))

    def _open_output(self, item, _column=0):
        path = item.data(0, Qt.ItemDataRole.UserRole)
        if path and os.path.isfile(path) and not self.shell.show_output(path):
            QDesktopServices.openUrl(QUrl.fromLocalFile(path))


def _size(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} GB"
