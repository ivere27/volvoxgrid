package main

import (
	"testing"

	pb "github.com/ivere27/volvoxgrid/api/v1"
)

func TestHandleHostInputInsertTogglesAutoStartEdit(t *testing.T) {
	controller := newDemoController(nil, demoSales)

	result, err := controller.HandleHostInput([]byte("\x1b[2~"), &pb.EditState{}, 80, 24)
	if err != nil {
		t.Fatalf("forward insert toggle: %v", err)
	}
	if string(result.ForwardedInput) != "\x1b[2~" {
		t.Fatalf("expected insert escape sequence to be forwarded, got %q", string(result.ForwardedInput))
	}
	if result.ChromeDirty || result.Render {
		t.Fatalf("expected insert toggle to stay host-neutral, got %+v", result)
	}
}

func TestHandleHostInputForwardsPrintableKeysOutsideSearchBindings(t *testing.T) {
	controller := newDemoController(nil, demoSales)

	result, err := controller.HandleHostInput([]byte("x"), &pb.EditState{}, 80, 24)
	if err != nil {
		t.Fatalf("printable key forwarding: %v", err)
	}
	if string(result.ForwardedInput) != "x" {
		t.Fatalf("expected printable key to be forwarded, got %q", string(result.ForwardedInput))
	}
	if result.ChromeDirty || result.Render {
		t.Fatalf("expected no redraw for forwarded input, got %+v", result)
	}
}

func TestHandleHostInputSearchPromptOpensInNavigationMode(t *testing.T) {
	controller := newDemoController(nil, demoSales)

	result, err := controller.HandleHostInput([]byte("/"), &pb.EditState{}, 80, 24)
	if err != nil {
		t.Fatalf("open search prompt: %v", err)
	}
	if !controller.search.promptActive {
		t.Fatalf("expected search prompt to be active")
	}
	if controller.search.status != "Search" {
		t.Fatalf("unexpected status %q", controller.search.status)
	}
	if len(result.ForwardedInput) != 0 || !result.ChromeDirty || !result.Render {
		t.Fatalf("expected local prompt handling, got %+v", result)
	}
}

func TestHandleHostInputSearchPromptClearsPreviousQuery(t *testing.T) {
	controller := newDemoController(nil, demoSales)
	controller.search.lastQuery = "previous"

	result, err := controller.HandleHostInput([]byte("/"), &pb.EditState{}, 80, 24)
	if err != nil {
		t.Fatalf("open cleared search prompt: %v", err)
	}
	if !controller.search.promptActive {
		t.Fatalf("expected search prompt to be active")
	}
	if controller.search.prompt != "" {
		t.Fatalf("expected fresh empty prompt, got %q", controller.search.prompt)
	}
	if controller.search.lastQuery != "previous" {
		t.Fatalf("expected previous query to remain available for repeat search, got %q", controller.search.lastQuery)
	}
	if len(result.ForwardedInput) != 0 || !result.ChromeDirty || !result.Render {
		t.Fatalf("expected local prompt handling, got %+v", result)
	}
}
