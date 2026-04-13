package volvoxgrid

import (
	"context"
	"errors"
	"fmt"
	"io"
	"runtime"
	"sync"
	"unsafe"

	synurang "github.com/ivere27/synurang/pkg/synurang"
	pb "github.com/ivere27/volvoxgrid/api/v1"
)

const defaultTerminalBufferCapacity = 32 * 1024

type Client struct {
	plugin *synurang.Plugin
	client pb.VolvoxGridServiceClient
}

func NewClient(pluginPath string) (*Client, error) {
	plugin, err := synurang.LoadPlugin(pluginPath)
	if err != nil {
		return nil, fmt.Errorf("load plugin: %w", err)
	}

	conn := synurang.NewPluginClientConn(plugin, "VolvoxGridService")
	return &Client{
		plugin: plugin,
		client: pb.NewVolvoxGridServiceClient(conn),
	}, nil
}

func (c *Client) Close() error {
	if c == nil || c.plugin == nil {
		return nil
	}
	return c.plugin.Close()
}

func (c *Client) GetDemoData(name string) ([]byte, error) {
	resp, err := c.client.GetDemoData(context.Background(), &pb.GetDemoDataRequest{
		Demo: name,
	})
	if err != nil {
		return nil, err
	}
	return append([]byte(nil), resp.GetData()...), nil
}

func (c *Client) NewGrid(width, height int) (*Grid, error) {
	resp, err := c.client.Create(context.Background(), &pb.CreateRequest{
		ViewportWidth:  int32(width),
		ViewportHeight: int32(height),
		Scale:          1.0,
	})
	if err != nil {
		return nil, err
	}
	gridID := resp.GetHandle().GetId()
	if gridID == 0 {
		return nil, errors.New("create grid returned zero handle")
	}
	return &Grid{
		client: c,
		ID:     gridID,
	}, nil
}

type Grid struct {
	client    *Client
	ID        int64
	destroyed bool
}

func (g *Grid) Configure(config *pb.GridConfig) error {
	_, err := g.client.client.Configure(context.Background(), &pb.ConfigureRequest{
		GridId: g.ID,
		Config: config,
	})
	return err
}

func (g *Grid) DefineColumns(columns []*pb.ColumnDef) error {
	_, err := g.client.client.DefineColumns(context.Background(), &pb.DefineColumnsRequest{
		GridId:  g.ID,
		Columns: columns,
	})
	return err
}

func (g *Grid) DefineRows(rows []*pb.RowDef) error {
	_, err := g.client.client.DefineRows(context.Background(), &pb.DefineRowsRequest{
		GridId: g.ID,
		Rows:   rows,
	})
	return err
}

func (g *Grid) UpdateCells(cells []*pb.CellUpdate, atomic bool) error {
	_, err := g.client.client.UpdateCells(context.Background(), &pb.UpdateCellsRequest{
		GridId: g.ID,
		Cells:  cells,
		Atomic: atomic,
	})
	return err
}

func (g *Grid) LoadData(data []byte, options *pb.LoadDataOptions) (*pb.LoadDataResult, error) {
	return g.client.client.LoadData(context.Background(), &pb.LoadDataRequest{
		GridId:  g.ID,
		Data:    data,
		Options: options,
	})
}

func (g *Grid) LoadTable(rows, cols int32, values []*pb.CellValue, atomic bool) (*pb.WriteResult, error) {
	return g.client.client.LoadTable(context.Background(), &pb.LoadTableRequest{
		GridId: g.ID,
		Rows:   rows,
		Cols:   cols,
		Values: values,
		Atomic: atomic,
	})
}

func (g *Grid) LoadDemo(name string) error {
	_, err := g.client.client.LoadDemo(context.Background(), &pb.LoadDemoRequest{
		GridId: g.ID,
		Demo:   name,
	})
	return err
}

func (g *Grid) Subtotal(
	aggregate pb.AggregateType,
	groupOnCol int32,
	aggregateCol int32,
	caption string,
	background uint32,
	foreground uint32,
	addOutline bool,
) (*pb.SubtotalResult, error) {
	return g.client.client.Subtotal(context.Background(), &pb.SubtotalRequest{
		GridId:       g.ID,
		Aggregate:    aggregate,
		GroupOnCol:   groupOnCol,
		AggregateCol: aggregateCol,
		Caption:      caption,
		Background:   background,
		Foreground:   foreground,
		AddOutline:   addOutline,
	})
}

func (g *Grid) GetNode(row int32) (*pb.NodeInfo, error) {
	return g.client.client.GetNode(context.Background(), &pb.GetNodeRequest{
		GridId: g.ID,
		Row:    row,
	})
}

func (g *Grid) MergeCells(row1, col1, row2, col2 int32) error {
	_, err := g.client.client.MergeCells(context.Background(), &pb.MergeCellsRequest{
		GridId: g.ID,
		Range: &pb.CellRange{
			Row1: row1,
			Col1: col1,
			Row2: row2,
			Col2: col2,
		},
	})
	return err
}

func (g *Grid) SetRedraw(enabled bool) error {
	_, err := g.client.client.SetRedraw(context.Background(), &pb.SetRedrawRequest{
		GridId:  g.ID,
		Enabled: enabled,
	})
	return err
}

func (g *Grid) Refresh() error {
	_, err := g.client.client.Refresh(context.Background(), &pb.GridHandle{Id: g.ID})
	return err
}

func (g *Grid) Clear(scope pb.ClearScope, region pb.ClearRegion) error {
	_, err := g.client.client.Clear(context.Background(), &pb.ClearRequest{
		GridId: g.ID,
		Scope:  scope,
		Region: region,
	})
	return err
}

func (g *Grid) CancelEdit() error {
	_, err := g.client.client.Edit(context.Background(), &pb.EditCommand{
		GridId: g.ID,
		Command: &pb.EditCommand_Cancel{
			Cancel: &pb.EditCancel{},
		},
	})
	return err
}

func (g *Grid) StartEdit(row, col int32, selectAll, caretEnd bool) (*pb.EditState, error) {
	return g.client.client.Edit(context.Background(), &pb.EditCommand{
		GridId: g.ID,
		Command: &pb.EditCommand_Start{
			Start: &pb.EditStart{
				Row:       row,
				Col:       col,
				SelectAll: ptr(selectAll),
				CaretEnd:  ptr(caretEnd),
			},
		},
	})
}

func (g *Grid) GetEditState() (*pb.EditState, error) {
	return g.client.client.Edit(context.Background(), &pb.EditCommand{
		GridId: g.ID,
	})
}

func (g *Grid) GetConfig() (*pb.GridConfig, error) {
	return g.client.client.GetConfig(context.Background(), &pb.GridHandle{Id: g.ID})
}

func (g *Grid) GetSelection() (*pb.SelectionState, error) {
	return g.client.client.GetSelection(context.Background(), &pb.GridHandle{Id: g.ID})
}

func (g *Grid) GetCells(
	row1,
	col1,
	row2,
	col2 int32,
	includeStyle,
	includeChecked,
	includeTyped bool,
) (*pb.CellsResponse, error) {
	return g.client.client.GetCells(context.Background(), &pb.GetCellsRequest{
		GridId:         g.ID,
		Row1:           row1,
		Col1:           col1,
		Row2:           row2,
		Col2:           col2,
		IncludeStyle:   includeStyle,
		IncludeChecked: includeChecked,
		IncludeTyped:   includeTyped,
	})
}

func (g *Grid) SelectCell(row, col int32, show bool) error {
	_, err := g.client.client.Select(context.Background(), &pb.SelectRequest{
		GridId:    g.ID,
		ActiveRow: row,
		ActiveCol: col,
		Ranges: []*pb.CellRange{
			{
				Row1: row,
				Col1: col,
				Row2: row,
				Col2: col,
			},
		},
		Show: ptr(show),
	})
	return err
}

func (g *Grid) ShowCell(row, col int32) error {
	_, err := g.client.client.ShowCell(context.Background(), &pb.ShowCellRequest{
		GridId: g.ID,
		Row:    row,
		Col:    col,
	})
	return err
}

func (g *Grid) FindText(col, startRow int32, text string, caseSensitive, fullMatch bool) (int32, error) {
	resp, err := g.client.client.Find(context.Background(), &pb.FindRequest{
		GridId:   g.ID,
		Col:      col,
		StartRow: startRow,
		Query: &pb.FindRequest_TextQuery{
			TextQuery: &pb.TextQuery{
				Text:          text,
				CaseSensitive: caseSensitive,
				FullMatch:     fullMatch,
			},
		},
	})
	if err != nil {
		return -1, err
	}
	return resp.GetRow(), nil
}

func (g *Grid) OpenTerminalSession() (*TerminalSession, error) {
	return newTerminalSession(g.client.client, g.ID)
}

func (g *Grid) Destroy() error {
	if g == nil || g.destroyed {
		return nil
	}
	g.destroyed = true
	_, err := g.client.client.Destroy(context.Background(), &pb.GridHandle{Id: g.ID})
	return err
}

type TerminalCapabilities struct {
	ColorLevel     pb.TerminalColorLevel
	SgrMouse       bool
	FocusEvents    bool
	BracketedPaste bool
}

type TerminalFrame struct {
	Buffer       []byte
	BytesWritten int
	Rendered     bool
	Kind         pb.FrameKind
	Metrics      *pb.FrameMetrics
}

type TerminalSession struct {
	gridID int64
	stream pb.VolvoxGridService_RenderSessionClient

	sendMu   sync.Mutex
	renderMu sync.Mutex

	capabilities      TerminalCapabilities
	capabilitiesDirty bool
	buffer            []byte
	originX           int32
	originY           int32
	width             int32
	height            int32
	fullscreen        bool
	viewportDirty     bool
	LastMetrics       *pb.FrameMetrics
	closed            bool
}

func newTerminalSession(client pb.VolvoxGridServiceClient, gridID int64) (*TerminalSession, error) {
	stream, err := client.RenderSession(context.Background())
	if err != nil {
		return nil, err
	}
	return &TerminalSession{
		gridID:            gridID,
		stream:            stream,
		capabilitiesDirty: true,
		viewportDirty:     true,
	}, nil
}

func (s *TerminalSession) SetCapabilities(capabilities TerminalCapabilities) {
	s.capabilities = capabilities
	s.capabilitiesDirty = true
}

func (s *TerminalSession) SetViewport(originX, originY, width, height int, fullscreen bool) {
	if width <= 0 || height <= 0 {
		return
	}
	nextOriginX := int32(originX)
	if nextOriginX < 0 {
		nextOriginX = 0
	}
	nextOriginY := int32(originY)
	if nextOriginY < 0 {
		nextOriginY = 0
	}
	nextWidth := int32(width)
	nextHeight := int32(height)
	if s.originX == nextOriginX &&
		s.originY == nextOriginY &&
		s.width == nextWidth &&
		s.height == nextHeight &&
		s.fullscreen == fullscreen &&
		!s.viewportDirty {
		return
	}

	s.originX = nextOriginX
	s.originY = nextOriginY
	s.width = nextWidth
	s.height = nextHeight
	s.fullscreen = fullscreen
	s.viewportDirty = true
}

func (s *TerminalSession) SendInputBytes(data []byte) error {
	if len(data) == 0 {
		return nil
	}
	return s.sendInput(&pb.RenderInput{
		GridId: s.gridID,
		Input: &pb.RenderInput_TerminalInput{
			TerminalInput: &pb.TerminalInputBytes{
				Data: append([]byte(nil), data...),
			},
		},
	})
}

func (s *TerminalSession) Render() (*TerminalFrame, error) {
	if s.width <= 0 || s.height <= 0 {
		return nil, errors.New("viewport must be set before render")
	}

	s.renderMu.Lock()
	defer s.renderMu.Unlock()

	if err := s.ensureTerminalStateSent(); err != nil {
		return nil, err
	}
	s.ensureBuffer(defaultTerminalBufferCapacity)
	return s.requestFrame()
}

func (s *TerminalSession) Shutdown() (*TerminalFrame, error) {
	s.renderMu.Lock()
	defer s.renderMu.Unlock()

	if err := s.sendInput(&pb.RenderInput{
		GridId: s.gridID,
		Input: &pb.RenderInput_TerminalCommand{
			TerminalCommand: &pb.TerminalCommand{
				Kind: pb.TerminalCommand_TERMINAL_COMMAND_EXIT,
			},
		},
	}); err != nil {
		return nil, err
	}

	s.ensureBuffer(256)
	return s.requestFrame()
}

func (s *TerminalSession) Close() error {
	if s == nil || s.closed {
		return nil
	}
	s.closed = true
	if closer, ok := any(s.stream).(interface{ CloseSend() error }); ok {
		return closer.CloseSend()
	}
	return nil
}

func (s *TerminalSession) ensureTerminalStateSent() error {
	if s.capabilitiesDirty {
		if err := s.sendInput(&pb.RenderInput{
			GridId: s.gridID,
			Input: &pb.RenderInput_TerminalCapabilities{
				TerminalCapabilities: &pb.TerminalCapabilities{
					ColorLevel:     s.capabilities.ColorLevel,
					SgrMouse:       s.capabilities.SgrMouse,
					FocusEvents:    s.capabilities.FocusEvents,
					BracketedPaste: s.capabilities.BracketedPaste,
				},
			},
		}); err != nil {
			return err
		}
		s.capabilitiesDirty = false
	}

	if s.viewportDirty {
		if err := s.sendInput(&pb.RenderInput{
			GridId: s.gridID,
			Input: &pb.RenderInput_TerminalViewport{
				TerminalViewport: &pb.TerminalViewport{
					OriginX:    s.originX,
					OriginY:    s.originY,
					Width:      s.width,
					Height:     s.height,
					Fullscreen: s.fullscreen,
				},
			},
		}); err != nil {
			return err
		}
		s.viewportDirty = false
	}

	return nil
}

func (s *TerminalSession) requestFrame() (*TerminalFrame, error) {
	for {
		handle := int64(uintptr(unsafe.Pointer(unsafe.SliceData(s.buffer))))
		if err := s.sendInput(&pb.RenderInput{
			GridId: s.gridID,
			Input: &pb.RenderInput_Buffer{
				Buffer: &pb.BufferReady{
					Handle:   handle,
					Capacity: int32(len(s.buffer)),
					Width:    s.width,
					Height:   s.height,
				},
			},
		}); err != nil {
			return nil, err
		}

		for {
			output, err := s.stream.Recv()
			if err != nil {
				if errors.Is(err, io.EOF) {
					return nil, errors.New("terminal render stream closed")
				}
				return nil, err
			}
			done := output.GetFrameDone()
			if done == nil || done.GetHandle() != handle {
				continue
			}
			if required := int(done.GetRequiredCapacity()); required > len(s.buffer) {
				s.ensureBuffer(required)
				break
			}

			s.LastMetrics = done.GetMetrics()
			frame := &TerminalFrame{
				Buffer:       s.buffer,
				BytesWritten: int(done.GetBytesWritten()),
				Rendered:     output.GetRendered(),
				Kind:         done.GetFrameKind(),
				Metrics:      done.GetMetrics(),
			}
			runtime.KeepAlive(s.buffer)
			return frame, nil
		}
	}
}

func (s *TerminalSession) sendInput(input *pb.RenderInput) error {
	s.sendMu.Lock()
	defer s.sendMu.Unlock()
	return s.stream.Send(input)
}

func (s *TerminalSession) ensureBuffer(capacity int) {
	target := capacity
	if target < defaultTerminalBufferCapacity {
		target = defaultTerminalBufferCapacity
	}
	if len(s.buffer) >= target {
		return
	}
	s.buffer = make([]byte, target)
}

func ptr[T any](value T) *T {
	return &value
}
