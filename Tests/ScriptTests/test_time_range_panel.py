import unittest
from pathlib import Path


SOURCES = Path(__file__).parents[2] / "Sources" / "MyIMEMacOS"


class TimeRangePanelTests(unittest.TestCase):
    """The range rail shares the time panel, its keys and its insertion"""

    def setUp(self):
        self.view = (SOURCES / "TimeRangeView.swift").read_text(encoding="utf-8")
        self.window = (SOURCES / "TimeWindowController.swift").read_text(
            encoding="utf-8"
        )
        self.controller = (SOURCES / "InputController.swift").read_text(
            encoding="utf-8"
        )
        self.state = (
            Path(__file__).parents[2]
            / "Sources"
            / "MyIMECore"
            / "TimeInputState.swift"
        ).read_text(encoding="utf-8")

    def body(self, source, signature):
        start = source.index(signature)
        return source[start:source.index("\n    }\n", start)]

    def test_keys_the_input_method_receives_go_to_the_rail(self):
        handle = self.body(self.window, "func handleKeyEvent(")
        self.assertIn("rangeView.handleKey(event)", handle)
        self.assertTrue(handle.rstrip().endswith("return true"))

    def test_the_shortcut_does_not_toggle_another_input_ui(self):
        handle = self.body(self.window, "func handleKeyEvent(")
        self.assertNotIn("handleShortcut()", handle)
        controller = self.window[self.window.index("final class TimeWindowController"):]
        self.assertNotIn("showClock()", controller)
        self.assertNotIn("showRange()", controller)

    def test_formats_are_shown_in_the_candidate_panel(self):
        # The time panel no longer draws formats of its own
        self.assertNotIn("drawFormatStage", self.window)
        self.assertNotIn("書式を選択", self.window)
        run = self.body(self.window, "func runFormatSelection(")
        self.assertIn("panel.orderOut(nil)", run)
        self.assertIn("NSApp.runModal(for: formatKeyPanel)", run)
        show = self.body(self.controller,
                         "private func showTimeFormatCandidates(")
        self.assertIn("primaryCandidatePanel.show(", show)
        load = self.body(self.controller, "private func loadTimeFormats(")
        self.assertLess(load.index("self.showTimeFormatCandidates(client: sender)"),
                        load.index("runTimeFormatSelection("))

    def test_keys_the_input_method_receives_go_to_the_format_key_panel(self):
        handle = self.body(self.controller,
                           "private func handleTimeFormatSelection(")
        self.assertLess(handle.index("timeWindow.handleFormatKey(event)"),
                        handle.index("switch event.keyCode"))
        back = self.body(self.controller, "private func returnToTimeSelection(")
        self.assertLess(back.index("timeWindow.cancelFormatSelection()"),
                        back.index("candidateSearchCoordinator.cancel"))

    def test_the_unified_rail_has_no_mode_button(self):
        self.assertNotIn("rangeButton", self.window)

    def test_escape_leaves_range_mode_before_closing(self):
        escape = self.body(self.window, "func handleEscape()")
        self.assertIn("rangeView.returnToTimeMode()", escape)
        self.assertIn("cancelSelection()", escape)

    def test_range_formats_are_chosen_like_those_of_a_time(self):
        load = self.body(self.controller, "private func loadTimeFormats(")
        self.assertIn("timeRangeFormats(range)", load)
        self.assertIn("accepts(formatsFor: range)", load)
        back = self.body(self.controller, "private func returnToTimeSelection(")
        self.assertIn("resumeTimeRangeSelection(", back)

    def test_holding_a_knob_still_is_checked_on_a_timer(self):
        start = self.body(self.view, "private func startStillnessTracking(")
        self.assertIn("Timer(timeInterval:", start)
        self.assertIn("forMode: .modalPanel", start)
        dragged = self.body(self.view, "override func mouseDragged(")
        self.assertIn("> Self.stillTolerance", dragged)
        self.assertIn("dragFinely(to: point)", dragged)
        self.assertIn("TimeRangeFineDrag(", self.view)
        self.assertNotIn("private struct FineDrag", self.view)

    def test_every_end_of_a_drag_drops_the_timer_and_the_hour(self):
        end = self.body(self.view, "func endDrag()")
        self.assertIn("stillnessTimer?.invalidate()", end)
        self.assertIn("fineDrag = nil", end)
        self.assertIn("endDrag()", self.body(self.view, "override func mouseUp("))
        self.assertIn("resetInteraction()", self.body(self.view, "func begin(with"))
        self.assertIn("endDrag()", self.body(self.view,
                                             "private func resetInteraction()"))
        for caller in ["func hide()", "func runSelection("]:
            with self.subTest(caller=caller):
                self.assertIn("rangeView.endDrag()",
                              self.body(self.window, caller))

    def test_only_voiceover_names_describe_the_parts(self):
        for label in ["選択時刻", "時刻のつまみ", "終了時刻のつまみ"]:
            self.assertIn(f'"{label}"', self.view)
        self.assertNotIn('"↵"', self.view)

    def test_time_preview_is_static_and_not_editable(self):
        self.assertIn("setAccessibilityRole(.staticText)", self.view)
        self.assertNotIn("setAccessibilityRole(.textField)", self.view)
        for editing_symbol in [
            "editingText",
            "showsInvalidText",
            "fieldRole(at:",
            "func edit(",
            "commitEditing",
            "selectedTextBackgroundColor",
        ]:
            with self.subTest(editing_symbol=editing_symbol):
                self.assertNotIn(editing_symbol, self.view)
        mouse_down = self.body(self.view, "override func mouseDown(")
        self.assertIn("knobHandle(at: point)", mouse_down)
        self.assertNotIn("previewRect.contains", mouse_down)

    def test_time_preview_uses_one_text_for_time_and_range(self):
        preview = self.body(self.view, "private var previewText:")
        self.assertIn('return "\\(start) 〜 \\(end)"', preview)
        self.assertIn("guard state.mode == .range else { return start }", preview)

    def test_transparent_parent_has_no_outer_background_or_shadow(self):
        draw = self.body(self.view, "override func draw(")
        self.assertIn("drawPreview()", draw)
        self.assertIn("drawRail()", draw)
        self.assertNotIn("bounds.insetBy", draw)
        self.assertIn("panel.backgroundColor = .clear", self.window)
        self.assertIn("panel.hasShadow = false", self.window)

    def test_preview_and_slider_are_separate_minimal_regions(self):
        preview = self.body(self.view, "private var previewRect:")
        self.assertIn("textSize.width", preview)
        self.assertIn("+ 24", preview)
        rail = self.body(self.view, "private var railRect:")
        self.assertIn("width: 276", rail)
        self.assertIn("height: 56", rail)

    def test_day_ticks_and_zoom_ticks_follow_the_spec(self):
        ticks = self.body(self.view, "private func tickMarks(")
        self.assertIn("by: 180", ticks)
        # 3, 9, 15 and 21 are labelled as well as 0, 6, 12, 18 and 24
        self.assertIn("label: String(minutes / 60),", ticks)
        self.assertNotIn("isMultiple(of: 360)", ticks)
        self.assertIn("stride(from: first, through: last, by: 5)", ticks)
        self.assertIn('label = "\\(minutes / 60)時"', ticks)
        self.assertIn("minutes.isMultiple(of: 10)", ticks)

    def test_zoom_warps_cursor_and_rebases_fine_drag(self):
        stillness = self.body(self.view, "private func checkStillness(")
        self.assertIn("zoomedKnobCenter = knobCenter(for: handle)", stillness)
        self.assertIn("warpCursor(to: zoomedKnobCenter)", stillness)
        self.assertIn("cursorX: Double(zoomedKnobCenter.x)", stillness)
        self.assertIn("ignoreDraggedEventsThrough", stillness)

        warp = self.body(self.view, "private func warpCursor(")
        self.assertIn("convert(localPoint, to: nil)", warp)
        self.assertIn("window.convertPoint(toScreen: windowPoint)", warp)
        self.assertIn("CGDisplayBounds(CGMainDisplayID())", warp)
        self.assertIn("CGWarpMouseCursorPosition", warp)

    def test_each_knob_uses_its_own_center_as_the_hit_target(self):
        knob = self.body(self.view, "private func knobHandle(")
        self.assertIn("knobCenter(for: handle)", knob)
        self.assertIn("<= knobHitRadius", knob)

    def test_grabbing_a_knob_does_not_move_it(self):
        down = self.body(self.view, "override func mouseDown(")
        self.assertNotIn("applyDragged", down)
        self.assertNotIn("apply(", down)

    def test_every_value_path_uses_five_minute_steps(self):
        self.assertIn(
            "private static let step = TimeRangeSelection.dragStep",
            self.view,
        )
        self.assertIn("moveFocusedEdge(by: -Self.step)", self.view)
        self.assertIn("moveFocusedEdge(by: Self.step)", self.view)

    def test_tab_only_switches_the_focused_handle(self):
        keys = self.body(self.view, "func handleKey(")
        self.assertIn("case 48:", keys)
        self.assertIn("focusedHandle == .upper ? .lower : .upper", keys)
        self.assertNotIn("event.characters", keys)

    def test_physical_handles_are_separate_from_chronological_roles(self):
        self.assertIn("enum Handle", self.state)
        self.assertIn("enum Role", self.state)
        self.assertIn("upperRoleAtEquality", self.state)
        self.assertIn("state.role(of: handle)", self.view)

    def test_dragging_outside_does_not_close_the_panel(self):
        cancel = self.body(self.window, "private func cancelIfOutside(")
        self.assertIn("!rangeView.isDragging", cancel)


if __name__ == "__main__":
    unittest.main()
