package tui

import (
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	pb "github.com/ivere27/volvoxgrid/api/v1"
	"github.com/ivere27/volvoxgrid/pkg/volvoxgrid"
)

const ActionToggleDebugPanel = "toggle-debug-panel"

type ShortcutSpec struct {
	Action      string
	Ctrl        byte
	FunctionKey int
}

type ActionOutcome struct {
	Quit        bool
	ChromeDirty bool
}

type Controller interface {
	EnsureSession(viewportWidth, viewportHeight int) (*volvoxgrid.TerminalSession, error)
	CurrentEditState() (*pb.EditState, error)
	CancelActiveEdit() error
	HandleAction(action string, viewportWidth, viewportHeight int) (ActionOutcome, error)
	DrawChrome(term *Terminal, width, height int, mode string) error
}

type HostInputResult struct {
	ForwardedInput []byte
	ChromeDirty    bool
	Render         bool
	Quit           bool
}

type HostInputHandler interface {
	HandleHostInput(input []byte, editState *pb.EditState, viewportWidth, viewportHeight int) (HostInputResult, error)
}

type DebugPanelContext struct {
	Width          int
	Height         int
	ViewportHeight int
	Mode           string
	EditState      *pb.EditState
	Capabilities   volvoxgrid.TerminalCapabilities
	RenderDuration time.Duration
	RenderFPS      float64
	Frame          *volvoxgrid.TerminalFrame
}

type DebugPanelProvider interface {
	DebugPanelVisible() bool
	DebugPanelRows() int
	ToggleDebugPanel() error
	DebugPanelLines(ctx DebugPanelContext) ([]string, error)
}

type RunOptions struct {
	MinWidth   int
	MinHeight  int
	HeaderRows int
	FooterRows int
	FrameDelay time.Duration
	Shortcuts  []ShortcutSpec
}

func DefaultRunOptions() RunOptions {
	return RunOptions{
		MinWidth:   20,
		MinHeight:  6,
		HeaderRows: 1,
		FooterRows: 1,
		FrameDelay: 16 * time.Millisecond,
	}
}

func Run(term *Terminal, controller Controller, options RunOptions) error {
	options = normalizeRunOptions(options)
	hostInputHandler, _ := controller.(HostInputHandler)
	debugPanel, _ := controller.(DebugPanelProvider)

	var (
		cancelled   bool
		lastWidth   = -1
		lastHeight  = -1
		chromeDirty = true
		session     *volvoxgrid.TerminalSession
		router      = newShortcutRouter(withBuiltInShortcuts(options.Shortcuts))
		needRender  = true
		animate     bool
		renderFPS   float64
		renderTime  time.Duration
	)

	sigCh := make(chan os.Signal, 2)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGWINCH)
	defer signal.Stop(sigCh)

	defer func() {
		if session == nil {
			return
		}
		if frame, err := session.Shutdown(); err == nil {
			_ = term.Write(frame.Buffer, frame.BytesWritten)
		}
	}()

	for !cancelled {
		if needRender {
			layout := currentLayout(term, options, debugPanel)
			width, height, viewportHeight := layout.width, layout.height, layout.viewportHeight
			if width != lastWidth || height != lastHeight {
				lastWidth = width
				lastHeight = height
				chromeDirty = true
			}

			activeSession, err := controller.EnsureSession(width, viewportHeight)
			if err != nil {
				return err
			}
			session = activeSession
			capabilities := term.DetectCapabilities()
			session.SetCapabilities(capabilities)
			session.SetViewport(0, layout.headerRows, width, viewportHeight, false)

			editState, err := controller.CurrentEditState()
			if err != nil {
				return err
			}
			mode := ModeLabel(editState)
			if chromeDirty {
				if err := controller.DrawChrome(term, width, height, mode); err != nil {
					return err
				}
				chromeDirty = false
			}

			renderStart := time.Now()
			frame, err := session.Render()
			if err != nil {
				return err
			}
			renderTime = time.Since(renderStart)
			renderFPS = updateRenderFPS(renderFPS, renderTime)
			if err := term.Write(frame.Buffer, frame.BytesWritten); err != nil {
				return err
			}
			if debugPanel != nil && debugPanel.DebugPanelVisible() {
				lines, err := debugPanel.DebugPanelLines(DebugPanelContext{
					Width:          width,
					Height:         height,
					ViewportHeight: viewportHeight,
					Mode:           mode,
					EditState:      editState,
					Capabilities:   capabilities,
					RenderDuration: renderTime,
					RenderFPS:      renderFPS,
					Frame:          frame,
				})
				if err != nil {
					return err
				}
				if err := drawDebugPanel(term, options.HeaderRows, width, debugPanelRows(debugPanel), lines); err != nil {
					return err
				}
			}

			needRender = false
			animate = frame.Rendered
			continue
		}

		var renderTimer <-chan time.Time
		if animate && options.FrameDelay > 0 {
			renderTimer = time.After(options.FrameDelay)
		}

		select {
		case sig := <-sigCh:
			if sig == os.Interrupt {
				cancelled = true
				continue
			}
			chromeDirty = true
			needRender = true
			animate = false

		case err := <-term.errorChannel():
			if err != nil {
				return err
			}

		case input := <-term.inputChannel():
			input = drainTermInput(term, input)
			layout := currentLayout(term, options, debugPanel)
			width, height, viewportHeight := layout.width, layout.height, layout.viewportHeight
			if width != lastWidth || height != lastHeight {
				lastWidth = width
				lastHeight = height
				chromeDirty = true
			}

			activeSession, err := controller.EnsureSession(width, viewportHeight)
			if err != nil {
				return err
			}
			session = activeSession
			session.SetCapabilities(term.DetectCapabilities())
			session.SetViewport(0, layout.headerRows, width, viewportHeight, false)

			editState, err := controller.CurrentEditState()
			if err != nil {
				return err
			}

			shortcutResult := router.Filter(input)
			forwardedInput := shortcutResult.ForwardedInput
			if hostInputHandler != nil && len(forwardedInput) > 0 {
				hostResult, err := hostInputHandler.HandleHostInput(
					forwardedInput,
					editState,
					width,
					viewportHeight,
				)
				if err != nil {
					return err
				}
				forwardedInput = hostResult.ForwardedInput
				if hostResult.ChromeDirty {
					chromeDirty = true
				}
				if hostResult.Render {
					needRender = true
				}
				if hostResult.Quit {
					cancelled = true
				}
			}
			if cancelled {
				continue
			}

			if len(forwardedInput) > 0 {
				if err := session.SendInputBytes(forwardedInput); err != nil {
					return err
				}
				needRender = true
			}

			if shortcutResult.Action == ActionToggleDebugPanel {
				if debugPanel != nil {
					if err := debugPanel.ToggleDebugPanel(); err != nil {
						return err
					}
					chromeDirty = true
					needRender = true
				}
			} else if shortcutResult.Action != "" {
				if err := controller.CancelActiveEdit(); err != nil {
					return err
				}
				outcome, err := controller.HandleAction(shortcutResult.Action, width, viewportHeight)
				if err != nil {
					return err
				}
				if outcome.ChromeDirty {
					chromeDirty = true
				}
				if outcome.Quit {
					cancelled = true
					continue
				}

				activeSession, err = controller.EnsureSession(width, viewportHeight)
				if err != nil {
					return err
				}
				session = activeSession
				session.SetCapabilities(term.DetectCapabilities())
				session.SetViewport(0, layout.headerRows, width, viewportHeight, false)
				needRender = true
			}

			if chromeDirty {
				needRender = true
			}
			animate = false

		case <-renderTimer:
			needRender = true
			animate = false
		}
	}

	return nil
}

type layoutState struct {
	width          int
	height         int
	headerRows     int
	footerRows     int
	viewportHeight int
}

func currentLayout(term *Terminal, options RunOptions, debugPanel DebugPanelProvider) layoutState {
	width := maxInt(options.MinWidth, term.Width())
	height := maxInt(options.MinHeight, term.Height())
	headerRows := maxInt(0, options.HeaderRows)
	footerRows := maxInt(0, options.FooterRows)
	if debugPanel != nil && debugPanel.DebugPanelVisible() {
		headerRows += debugPanelRows(debugPanel)
	}
	viewportHeight := maxInt(1, height-headerRows-footerRows)
	return layoutState{
		width:          width,
		height:         height,
		headerRows:     headerRows,
		footerRows:     footerRows,
		viewportHeight: viewportHeight,
	}
}

func drainTermInput(term *Terminal, initial []byte) []byte {
	merged := append([]byte(nil), initial...)
	for {
		select {
		case next := <-term.inputChannel():
			merged = append(merged, next...)
		default:
			return merged
		}
	}
}

func ModeLabel(state *pb.EditState) string {
	if state == nil || !state.GetActive() {
		return "Ready"
	}
	if state.GetUiMode() == pb.EditUiMode_EDIT_UI_MODE_EDIT {
		return "Edit"
	}
	return "Enter"
}

type ShortcutResult struct {
	ForwardedInput []byte
	Action         string
}

type shortcutRouter struct {
	specs   []ShortcutSpec
	pending []byte
}

func newShortcutRouter(specs []ShortcutSpec) *shortcutRouter {
	copied := make([]ShortcutSpec, 0, len(specs))
	for _, spec := range specs {
		if strings.TrimSpace(spec.Action) == "" {
			continue
		}
		copied = append(copied, spec)
	}
	return &shortcutRouter{specs: copied}
}

func withBuiltInShortcuts(specs []ShortcutSpec) []ShortcutSpec {
	all := make([]ShortcutSpec, 0, len(specs)+1)
	all = append(all, ShortcutSpec{
		Action:      ActionToggleDebugPanel,
		FunctionKey: 12,
	})
	all = append(all, specs...)
	return all
}

func (r *shortcutRouter) Filter(input []byte) ShortcutResult {
	mergedInput := r.mergePending(input)
	if len(mergedInput) == 0 {
		return ShortcutResult{}
	}

	forwarded := make([]byte, 0, len(mergedInput))
	index := 0
	for index < len(mergedInput) {
		value := mergedInput[index]
		if action := r.matchCtrl(value); action != "" {
			return ShortcutResult{
				ForwardedInput: forwarded,
				Action:         action,
			}
		}

		if value == 0x1B {
			functionKey, consumed, state := decodeFunctionKey(mergedInput, index)
			switch state {
			case escapeSequenceNeedMoreData:
				r.savePending(mergedInput[index:])
				return ShortcutResult{ForwardedInput: forwarded}
			case escapeSequenceMatched:
				if action := r.matchFunctionKey(functionKey); action != "" {
					return ShortcutResult{
						ForwardedInput: forwarded,
						Action:         action,
					}
				}
				forwarded = append(forwarded, mergedInput[index:index+consumed]...)
				index += consumed
				continue
			}

			forwardedConsumed := copyEscapeSequence(mergedInput, index, &forwarded)
			if forwardedConsumed <= 0 {
				r.savePending(mergedInput[index:])
				return ShortcutResult{ForwardedInput: forwarded}
			}
			index += forwardedConsumed
			continue
		}

		forwarded = append(forwarded, value)
		index++
	}

	return ShortcutResult{ForwardedInput: forwarded}
}

type escapeSequenceState int

const (
	escapeSequenceNoMatch escapeSequenceState = iota
	escapeSequenceMatched
	escapeSequenceNeedMoreData
)

func (r *shortcutRouter) mergePending(input []byte) []byte {
	if len(r.pending) == 0 {
		return input
	}
	merged := make([]byte, 0, len(r.pending)+len(input))
	merged = append(merged, r.pending...)
	merged = append(merged, input...)
	r.pending = r.pending[:0]
	return merged
}

func (r *shortcutRouter) savePending(input []byte) {
	r.pending = append(r.pending[:0], input...)
}

func (r *shortcutRouter) matchCtrl(value byte) string {
	for _, spec := range r.specs {
		if spec.Ctrl != 0 && spec.Ctrl == value {
			return spec.Action
		}
	}
	return ""
}

func (r *shortcutRouter) matchFunctionKey(key int) string {
	for _, spec := range r.specs {
		if spec.FunctionKey != 0 && spec.FunctionKey == key {
			return spec.Action
		}
	}
	return ""
}

func decodeFunctionKey(input []byte, start int) (int, int, escapeSequenceState) {
	remaining := len(input) - start
	if remaining <= 1 {
		return 0, 0, escapeSequenceNoMatch
	}

	second := input[start+1]
	if second == 'O' {
		if remaining < 3 {
			return 0, 0, escapeSequenceNeedMoreData
		}
		switch input[start+2] {
		case 'P':
			return 1, 3, escapeSequenceMatched
		case 'Q':
			return 2, 3, escapeSequenceMatched
		case 'R':
			return 3, 3, escapeSequenceMatched
		case 'S':
			return 4, 3, escapeSequenceMatched
		default:
			return 0, 3, escapeSequenceNoMatch
		}
	}
	if second != '[' {
		return 0, 2, escapeSequenceNoMatch
	}

	index := start + 2
	for index < len(input) {
		value := input[index]
		if isEscapeTerminator(value) {
			index++
			break
		}
		index++
	}

	if index > len(input) {
		return 0, 0, escapeSequenceNeedMoreData
	}
	if index == len(input) && !isEscapeTerminator(input[index-1]) {
		return 0, 0, escapeSequenceNeedMoreData
	}

	consumed := index - start
	if input[index-1] != '~' {
		return 0, consumed, escapeSequenceNoMatch
	}

	payload := string(input[start+2 : index-1])
	if sep := strings.IndexByte(payload, ';'); sep >= 0 {
		payload = payload[:sep]
	}
	switch payload {
	case "11":
		return 1, consumed, escapeSequenceMatched
	case "12":
		return 2, consumed, escapeSequenceMatched
	case "13":
		return 3, consumed, escapeSequenceMatched
	case "14":
		return 4, consumed, escapeSequenceMatched
	case "15":
		return 5, consumed, escapeSequenceMatched
	case "17":
		return 6, consumed, escapeSequenceMatched
	case "18":
		return 7, consumed, escapeSequenceMatched
	case "19":
		return 8, consumed, escapeSequenceMatched
	case "20":
		return 9, consumed, escapeSequenceMatched
	case "21":
		return 10, consumed, escapeSequenceMatched
	case "23":
		return 11, consumed, escapeSequenceMatched
	case "24":
		return 12, consumed, escapeSequenceMatched
	default:
		return 0, consumed, escapeSequenceNoMatch
	}
}

func copyEscapeSequence(input []byte, start int, forwarded *[]byte) int {
	remaining := len(input) - start
	if remaining <= 0 {
		return 0
	}
	if remaining == 1 {
		*forwarded = append(*forwarded, input[start])
		return 1
	}

	second := input[start+1]
	if second == 'O' {
		if remaining < 3 {
			return 0
		}
		*forwarded = append(*forwarded, input[start:start+3]...)
		return 3
	}
	if second != '[' {
		*forwarded = append(*forwarded, input[start:start+2]...)
		return 2
	}

	index := start + 2
	for index < len(input) {
		value := input[index]
		if isEscapeTerminator(value) {
			index++
			break
		}
		index++
	}
	if index > len(input) {
		return 0
	}
	if index == len(input) && !isEscapeTerminator(input[index-1]) {
		return 0
	}

	consumed := index - start
	*forwarded = append(*forwarded, input[start:index]...)
	return consumed
}

func isEscapeTerminator(value byte) bool {
	return (value >= 'A' && value <= 'Z') ||
		(value >= 'a' && value <= 'z') ||
		value == '~'
}

func normalizeRunOptions(options RunOptions) RunOptions {
	defaults := DefaultRunOptions()
	if options.MinWidth <= 0 {
		options.MinWidth = defaults.MinWidth
	}
	if options.MinHeight <= 0 {
		options.MinHeight = defaults.MinHeight
	}
	if options.HeaderRows < 0 {
		options.HeaderRows = defaults.HeaderRows
	}
	if options.FooterRows < 0 {
		options.FooterRows = defaults.FooterRows
	}
	if options.FrameDelay <= 0 {
		options.FrameDelay = defaults.FrameDelay
	}
	return options
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func updateRenderFPS(current float64, renderTime time.Duration) float64 {
	if renderTime <= 0 {
		return current
	}
	inst := float64(time.Second) / float64(renderTime)
	if current <= 0 {
		return inst
	}
	return current*0.9 + inst*0.1
}

func debugPanelRows(debugPanel DebugPanelProvider) int {
	if debugPanel == nil {
		return 0
	}
	rows := debugPanel.DebugPanelRows()
	if rows <= 0 {
		return 1
	}
	return rows
}

func drawDebugPanel(term *Terminal, baseHeaderRows, width, rows int, lines []string) error {
	var builder strings.Builder
	for i := 0; i < rows; i++ {
		line := ""
		if i < len(lines) {
			line = lines[i]
		}
		builder.WriteString(fmt.Sprintf("\x1b[%d;1H\x1b[0m%s", maxInt(1, baseHeaderRows+1+i), fitChromeLine(line, width)))
	}
	return term.WriteString(builder.String())
}

func fitChromeLine(text string, width int) string {
	if width <= 0 {
		return ""
	}
	switch {
	case len(text) > width:
		return text[:width]
	case len(text) < width:
		return text + strings.Repeat(" ", width-len(text))
	default:
		return text
	}
}
