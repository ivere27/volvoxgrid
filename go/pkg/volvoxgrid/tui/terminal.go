package tui

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"syscall"
	"unsafe"

	pb "github.com/ivere27/volvoxgrid/api/v1"
	"github.com/ivere27/volvoxgrid/pkg/volvoxgrid"
)

const (
	linuxTIOCGWINSZ  = 0x5413
	darwinTIOCGWINSZ = 0x40087468
)

type Terminal struct {
	stdout         *os.File
	savedSttyState string
	capabilities   volvoxgrid.TerminalCapabilities
	inputCh        chan []byte
	errCh          chan error
	closeCh        chan struct{}
	closed         bool
}

func NewTerminal() (*Terminal, error) {
	if runtime.GOOS == "windows" {
		return nil, errors.New("the Go thin terminal sample currently supports Unix-like terminals only")
	}

	savedState, err := runStty(true, "-g")
	if err != nil {
		return nil, err
	}
	if _, err := runStty(false, "cbreak", "-echo", "-ixon", "min", "1", "time", "0"); err != nil {
		return nil, err
	}

	terminal := &Terminal{
		stdout:         os.Stdout,
		savedSttyState: strings.TrimSpace(savedState),
		capabilities:   detectTerminalCapabilities(),
		inputCh:        make(chan []byte, 16),
		errCh:          make(chan error, 1),
		closeCh:        make(chan struct{}),
	}
	go terminal.readLoop()
	return terminal, nil
}

func IsInteractive() bool {
	in, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	out, err := os.Stdout.Stat()
	if err != nil {
		return false
	}
	return (in.Mode()&os.ModeCharDevice) != 0 && (out.Mode()&os.ModeCharDevice) != 0
}

func (t *Terminal) Width() int {
	if cols, _, ok := tryGetTerminalSize(int(os.Stdout.Fd())); ok {
		return cols
	}
	return 80
}

func (t *Terminal) Height() int {
	if _, rows, ok := tryGetTerminalSize(int(os.Stdout.Fd())); ok {
		return rows
	}
	return 24
}

func (t *Terminal) DetectCapabilities() volvoxgrid.TerminalCapabilities {
	return t.capabilities
}

func (t *Terminal) ReadInput() ([]byte, error) {
	out := make([]byte, 0, 2048)
	for {
		select {
		case data := <-t.inputCh:
			out = append(out, data...)
		case err := <-t.errCh:
			return out, err
		default:
			return out, nil
		}
	}
}

func (t *Terminal) Write(buffer []byte, count int) error {
	if count <= 0 || len(buffer) == 0 {
		return nil
	}
	if count > len(buffer) {
		count = len(buffer)
	}
	return writeAll(t.stdout, buffer[:count])
}

func (t *Terminal) WriteString(text string) error {
	if text == "" {
		return nil
	}
	return writeAll(t.stdout, []byte(text))
}

func (t *Terminal) Close() error {
	if t == nil || t.closed {
		return nil
	}
	t.closed = true
	close(t.closeCh)

	_ = t.WriteString("\x1b[0m\x1b[?25h\x1b[?1006l\x1b[?1002l\x1b[?1000l\x1b[?1004l\x1b[?2004l")
	if t.savedSttyState != "" {
		_, _ = runStty(false, t.savedSttyState)
	}
	return nil
}

func (t *Terminal) inputChannel() <-chan []byte {
	return t.inputCh
}

func (t *Terminal) errorChannel() <-chan error {
	return t.errCh
}

func (t *Terminal) readLoop() {
	buffer := make([]byte, 2048)
	for {
		n, err := os.Stdin.Read(buffer)
		if n > 0 {
			data := append([]byte(nil), buffer[:n]...)
			select {
			case t.inputCh <- data:
			case <-t.closeCh:
				return
			}
		}
		if err == nil {
			continue
		}
		if errors.Is(err, io.EOF) ||
			errors.Is(err, syscall.EAGAIN) ||
			errors.Is(err, syscall.EWOULDBLOCK) ||
			errors.Is(err, syscall.EINTR) {
			continue
		}
		select {
		case t.errCh <- err:
		case <-t.closeCh:
		default:
		}
		return
	}
}

func writeAll(file *os.File, data []byte) error {
	for len(data) > 0 {
		written, err := file.Write(data)
		if err != nil {
			return err
		}
		data = data[written:]
	}
	return nil
}

func detectTerminalCapabilities() volvoxgrid.TerminalCapabilities {
	term := strings.ToLower(os.Getenv("TERM"))
	colorTerm := strings.ToLower(os.Getenv("COLORTERM"))

	colorLevel := volvoxgrid.TerminalCapabilities{
		ColorLevel:     pb.TerminalColorLevel_TERMINAL_COLOR_LEVEL_AUTO,
		SgrMouse:       true,
		FocusEvents:    true,
		BracketedPaste: true,
	}
	switch {
	case strings.Contains(colorTerm, "truecolor"), strings.Contains(colorTerm, "24bit"):
		colorLevel.ColorLevel = pb.TerminalColorLevel_TERMINAL_COLOR_LEVEL_TRUECOLOR
	case strings.Contains(term, "256color"):
		colorLevel.ColorLevel = pb.TerminalColorLevel_TERMINAL_COLOR_LEVEL_256
	default:
		colorLevel.ColorLevel = pb.TerminalColorLevel_TERMINAL_COLOR_LEVEL_16
	}
	return colorLevel
}

func runStty(captureOutput bool, args ...string) (string, error) {
	cmd := exec.Command("stty", args...)
	cmd.Stdin = os.Stdin
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	if captureOutput {
		cmd.Stdout = &stdout
	}
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		if stderr.Len() == 0 {
			return "", fmt.Errorf("stty %s failed: %w", strings.Join(args, " "), err)
		}
		return "", fmt.Errorf("stty %s failed: %s", strings.Join(args, " "), strings.TrimSpace(stderr.String()))
	}
	return stdout.String(), nil
}

func tryGetTerminalSize(fd int) (cols, rows int, ok bool) {
	var request uintptr
	switch runtime.GOOS {
	case "darwin":
		request = darwinTIOCGWINSZ
	case "linux":
		request = linuxTIOCGWINSZ
	default:
		return 0, 0, false
	}

	var size struct {
		Rows    uint16
		Cols    uint16
		Xpixels uint16
		Ypixels uint16
	}
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, uintptr(fd), request, uintptr(unsafe.Pointer(&size)))
	if errno != 0 {
		return 0, 0, false
	}
	if size.Cols <= 1 || size.Rows <= 1 {
		return 0, 0, false
	}
	return int(size.Cols), int(size.Rows), true
}
