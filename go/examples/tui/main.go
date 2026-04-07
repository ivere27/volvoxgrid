package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/ivere27/volvoxgrid/pkg/volvoxgrid"
	vgterm "github.com/ivere27/volvoxgrid/pkg/volvoxgrid/tui"
)

func main() {
	if err := runMain(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func runMain(args []string) error {
	pluginPath, err := resolvePluginPath(args)
	if err != nil {
		return err
	}

	host, err := volvoxgrid.NewClient(pluginPath)
	if err != nil {
		return err
	}
	defer func() {
		_ = host.Close()
	}()

	if readBoolEnv("VOLVOXGRID_GO_TUI_SMOKE_MODE", false) ||
		readBoolEnv("VOLVOXGRID_TUI_SMOKE_MODE", false) ||
		hasArg(args, "--smoke") {
		return runSmoke(host)
	}

	if !vgterm.IsInteractive() {
		return fmt.Errorf("VolvoxGrid Go TUI sample requires an interactive terminal. Use --smoke or VOLVOXGRID_GO_TUI_SMOKE_MODE=1 for non-interactive checks")
	}

	terminal, err := vgterm.NewTerminal()
	if err != nil {
		return err
	}
	defer func() {
		_ = terminal.Close()
	}()

	controller := newDemoController(host, parseDemo(args))
	defer func() {
		_ = controller.Close()
	}()

	return vgterm.Run(terminal, controller, sampleRunOptions())
}

func resolvePluginPath(args []string) (string, error) {
	for _, value := range args {
		if !strings.HasPrefix(value, "--") {
			return value, nil
		}
	}
	if value := strings.TrimSpace(os.Getenv("VOLVOXGRID_PLUGIN_PATH")); value != "" {
		return value, nil
	}
	return "", fmt.Errorf("plugin path not found. Provide it as the first positional argument or set VOLVOXGRID_PLUGIN_PATH")
}

func parseDemo(args []string) demoKind {
	for index := 0; index < len(args)-1; index++ {
		if !strings.EqualFold(args[index], "--demo") {
			continue
		}
		switch strings.ToLower(strings.TrimSpace(args[index+1])) {
		case "sales":
			return demoSales
		case "hierarchy":
			return demoHierarchy
		case "stress":
			return demoStress
		}
	}
	return demoSales
}

func hasArg(args []string, flag string) bool {
	for _, value := range args {
		if strings.EqualFold(value, flag) {
			return true
		}
	}
	return false
}

func readBoolEnv(name string, defaultValue bool) bool {
	value := strings.TrimSpace(strings.ToLower(os.Getenv(name)))
	switch value {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return defaultValue
	}
}
