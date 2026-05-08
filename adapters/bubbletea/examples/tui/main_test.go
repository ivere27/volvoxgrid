package main

import (
	"os"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func exampleTestLibraryPath(t *testing.T) string {
	t.Helper()
	if path := os.Getenv("VOLVOXGRID_TEST_LIBRARY"); path != "" {
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("VOLVOXGRID_TEST_LIBRARY %q is not usable: %v", path, err)
		}
		return path
	}
	path := "../../../../target/debug/libvolvoxgrid.so"
	if _, err := os.Stat(path); err != nil {
		t.Skipf("native library not available at %s; set VOLVOXGRID_TEST_LIBRARY to run example integration tests", path)
	}
	return path
}

func TestFunctionKeysSwitchDemos(t *testing.T) {
	app := &appModel{
		libraryPath: exampleTestLibraryPath(t),
		currentDemo: demoSales,
		width:       80,
		height:      24,
	}
	t.Cleanup(func() {
		_ = app.Close()
	})

	if cmd := app.Init(); cmd == nil {
		t.Fatalf("expected initial adapter command")
	}
	if err := app.grid.Refresh(); err != nil {
		t.Fatalf("initial refresh: %v", err)
	}
	initialGridID := app.grid.GridID()
	if initialGridID == 0 {
		t.Fatalf("expected non-zero native grid id")
	}

	app.Update(tea.KeyMsg{Type: tea.KeyF12})
	if !app.debugPanel {
		t.Fatalf("F12 did not enable debug panel")
	}
	if text := stripANSI(app.View()); !strings.Contains(text, "DBG demo=Sales") {
		t.Fatalf("debug panel view missing DBG line: %q", text)
	}
	app.Update(tea.KeyMsg{Type: tea.KeyF12})
	if app.debugPanel {
		t.Fatalf("second F12 did not disable debug panel")
	}

	tests := []struct {
		key     tea.KeyType
		want    demoKind
		markers []string
	}{
		{tea.KeyF5, demoSimple, []string{"Atlas Desk", "Ledger Pro"}},
		{tea.KeyF7, demoHierarchy, []string{"Documents", "Reports"}},
		{tea.KeyF8, demoStress, []string{"Currency", "[x]"}},
		{tea.KeyF6, demoSales, []string{"Sensor M1", "Widget B"}},
	}
	for _, tt := range tests {
		_, _ = app.Update(tea.KeyMsg{Type: tt.key})
		if app.currentDemo != tt.want {
			t.Fatalf("current demo after %v = %s, want %s", tt.key, app.currentDemo.title(), tt.want.title())
		}
		if got := app.grid.GridID(); got != initialGridID {
			t.Fatalf("grid id after %v = %d, want same session grid id %d", tt.key, got, initialGridID)
		}
		text := stripANSI(app.View())
		for _, marker := range tt.markers {
			if !strings.Contains(text, marker) {
				t.Fatalf("view after %v missing marker %q:\n%s", tt.key, marker, text)
			}
		}
	}
}

func TestSwitchSimpleToSalesClearsSpannedCells(t *testing.T) {
	app := &appModel{
		libraryPath: exampleTestLibraryPath(t),
		currentDemo: demoSimple,
		width:       80,
		height:      24,
	}
	t.Cleanup(func() {
		_ = app.Close()
	})

	if cmd := app.Init(); cmd == nil {
		t.Fatalf("expected initial adapter command")
	}
	if err := app.grid.Refresh(); err != nil {
		t.Fatalf("refresh simple demo: %v", err)
	}
	simple := stripANSI(app.grid.View())
	if !strings.Contains(simple, "Atlas Desk") {
		t.Fatalf("simple demo did not render expected row: %q", simple)
	}

	_, _ = app.Update(tea.KeyMsg{Type: tea.KeyF6})
	if app.currentDemo != demoSales {
		t.Fatalf("current demo = %s, want Sales", app.currentDemo.title())
	}
	sales := stripANSI(app.grid.View())
	if strings.Contains(sales, "Atlas Desk") || strings.Contains(sales, "Ledger Pro") {
		t.Fatalf("sales view leaked simple demo cells after F5 -> F6 switch:\n%s", sales)
	}
	if !strings.Contains(sales, "Sensor M1") {
		t.Fatalf("sales demo did not render expected row after F5 -> F6 switch:\n%s", sales)
	}
	if strings.Contains(sales, "1║Q1│North") || strings.Contains(sales, "1║Q1 │North") {
		t.Fatalf("sales spanned Q/Region cells retained simple demo text after F5 -> F6 switch:\n%s", sales)
	}
	firstRow := findLineContaining(sales, "1║", "Sensor M1")
	if firstRow == "" {
		t.Fatalf("sales first row missing Sensor M1 after F5 -> F6 switch:\n%s", sales)
	}
	prefix, _, _ := strings.Cut(firstRow, "Sensors")
	if strings.Contains(prefix, "Q1") || strings.Contains(prefix, "East") {
		t.Fatalf("sales first row did not render blank spanned Q/Region cells after F5 -> F6 switch:\n%s", sales)
	}
}

func TestSwitchDemosDoNotLeakNativeConfig(t *testing.T) {
	libraryPath := exampleTestLibraryPath(t)
	app := &appModel{
		libraryPath: libraryPath,
		currentDemo: demoSales,
		width:       80,
		height:      24,
	}
	t.Cleanup(func() {
		_ = app.Close()
	})

	if cmd := app.Init(); cmd == nil {
		t.Fatalf("expected initial adapter command")
	}
	if err := app.grid.Refresh(); err != nil {
		t.Fatalf("refresh initial demo: %v", err)
	}

	_, _ = app.Update(tea.KeyMsg{Type: tea.KeyF7})
	if app.currentDemo != demoHierarchy {
		t.Fatalf("current demo = %s, want Hierarchy", app.currentDemo.title())
	}
	hierarchy := stripANSI(app.grid.View())
	if !lineFieldContains(hierarchy, "├─▾ Reports", "Folder") {
		t.Fatalf("hierarchy Type column inherited Sales span state after F6 -> F7 switch:\n%s", hierarchy)
	}
	if !lineFieldContains(hierarchy, "Q1_Report.xlsx", "File") {
		t.Fatalf("hierarchy file rows inherited Sales span state after F6 -> F7 switch:\n%s", hierarchy)
	}
}

func findLineContaining(text string, needles ...string) string {
	for _, line := range strings.Split(text, "\n") {
		matches := true
		for _, needle := range needles {
			if !strings.Contains(line, needle) {
				matches = false
				break
			}
		}
		if matches {
			return line
		}
	}
	return ""
}

func lineFieldContains(text, lineNeedle, value string) bool {
	line := findLineContaining(text, lineNeedle)
	if line == "" {
		return false
	}
	_, rest, found := strings.Cut(line, "║")
	if !found {
		return false
	}
	field, _, _ := strings.Cut(rest, "│")
	return strings.Contains(field, value)
}
