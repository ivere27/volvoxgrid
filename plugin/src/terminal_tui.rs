use std::cmp;

use volvoxgrid_engine::canvas_tui::{
    TuiCell, TuiRenderer, TUI_ATTR_BOLD, TUI_ATTR_ITALIC, TUI_ATTR_REVERSE, TUI_ATTR_UNDERLINE,
    TUI_COLOR_RESET,
};
use volvoxgrid_engine::grid::VolvoxGrid;
use volvoxgrid_engine::proto::volvoxgrid::v1 as pb;

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct TerminalViewportState {
    pub origin_x: i32,
    pub origin_y: i32,
    pub width: i32,
    pub height: i32,
    pub fullscreen: bool,
}

#[derive(Clone, Debug)]
pub enum TerminalEvent {
    Key(pb::KeyEvent),
    Pointer(pb::PointerEvent),
    Scroll(pb::ScrollEvent),
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TerminalKeyPolicyDecision {
    Forward,
    Consume,
    StartEdit { caret_end: bool },
    ToggleCompose { enabled: bool },
    RemapKeyDown { key_code: i32, modifier: i32 },
}

#[derive(Clone, Debug)]
struct TerminalCommit {
    session_started: bool,
    previous_cells: Vec<TuiCell>,
    previous_viewport: Option<TerminalViewportState>,
    pending_shutdown: bool,
    force_full_repaint: bool,
}

pub struct PreparedTerminalFrame {
    pub bytes: Vec<u8>,
    pub rendered: bool,
    pub frame_kind: i32,
    pub required_capacity: usize,
    commit: Option<TerminalCommit>,
}

impl PreparedTerminalFrame {
    pub fn commit(self, session: &mut TerminalTuiSession) {
        let Some(commit) = self.commit else {
            return;
        };
        session.session_started = commit.session_started;
        session.previous_cells = commit.previous_cells;
        session.previous_viewport = commit.previous_viewport;
        session.pending_shutdown = commit.pending_shutdown;
        session.force_full_repaint = commit.force_full_repaint;
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
struct TerminalCapabilitiesState {
    color_level: i32,
    sgr_mouse: bool,
    focus_events: bool,
    bracketed_paste: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct MousePoint {
    x: i32,
    y: i32,
    modifiers: i32,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ParsedTerminalEvent {
    Key {
        key_code: i32,
        modifiers: i32,
        character: Option<char>,
    },
    Pointer {
        point: MousePoint,
        event_type: i32,
        button: i32,
    },
    Scroll {
        point: MousePoint,
        delta_x: i32,
        delta_y: i32,
    },
}

#[derive(Clone, Debug, Default)]
struct TerminalInputParser {
    pending: Vec<u8>,
    paste_mode: bool,
    paste_buffer: Vec<u8>,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
struct TerminalStyle {
    fg: u32,
    bg: u32,
    attr: u8,
}

pub struct TerminalTuiSession {
    capabilities: TerminalCapabilitiesState,
    viewport: Option<TerminalViewportState>,
    parser: TerminalInputParser,
    auto_start_edit: bool,
    compose_enabled: bool,
    compose_initialized: bool,
    cells: Vec<TuiCell>,
    previous_cells: Vec<TuiCell>,
    previous_viewport: Option<TerminalViewportState>,
    session_started: bool,
    pending_shutdown: bool,
    force_full_repaint: bool,
    tui_scrollbar_drag_active: bool,
    tui_scrollbar_drag_start_y: i32,
    tui_scrollbar_drag_start_top_row: i32,
    tui_scrollbar_drag_start_thumb: i32,
}

impl Default for TerminalTuiSession {
    fn default() -> Self {
        Self {
            capabilities: TerminalCapabilitiesState {
                color_level: pb::TerminalColorLevel::Auto as i32,
                sgr_mouse: true,
                focus_events: true,
                bracketed_paste: true,
            },
            viewport: None,
            parser: TerminalInputParser::default(),
            auto_start_edit: false,
            compose_enabled: true,
            compose_initialized: false,
            cells: Vec::new(),
            previous_cells: Vec::new(),
            previous_viewport: None,
            session_started: false,
            pending_shutdown: false,
            force_full_repaint: true,
            tui_scrollbar_drag_active: false,
            tui_scrollbar_drag_start_y: 0,
            tui_scrollbar_drag_start_top_row: 0,
            tui_scrollbar_drag_start_thumb: 0,
        }
    }
}

impl TerminalTuiSession {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn is_active(&self) -> bool {
        self.viewport.is_some()
    }

    pub fn suppress_aux_outputs(&self) -> bool {
        self.is_active()
    }

    pub fn update_capabilities(&mut self, caps: &pb::TerminalCapabilities) {
        let next = TerminalCapabilitiesState {
            color_level: caps.color_level,
            sgr_mouse: caps.sgr_mouse,
            focus_events: caps.focus_events,
            bracketed_paste: caps.bracketed_paste,
        };
        if self.capabilities != next {
            self.capabilities = next;
            self.force_full_repaint = true;
        }
    }

    pub fn update_viewport(&mut self, viewport: &pb::TerminalViewport) -> bool {
        let next = TerminalViewportState {
            origin_x: viewport.origin_x.max(0),
            origin_y: viewport.origin_y.max(0),
            width: viewport.width.max(0),
            height: viewport.height.max(0),
            fullscreen: viewport.fullscreen,
        };
        let changed = self.viewport != Some(next);
        if changed {
            self.force_full_repaint = true;
            self.stop_tui_scrollbar_drag();
        }
        self.viewport = Some(next);
        changed
    }

    pub fn queue_shutdown(&mut self) {
        self.pending_shutdown = true;
        self.stop_tui_scrollbar_drag();
    }

    pub fn start_tui_scrollbar_drag(&mut self, start_y: i32, start_top_row: i32, start_thumb: i32) {
        self.tui_scrollbar_drag_active = true;
        self.tui_scrollbar_drag_start_y = start_y;
        self.tui_scrollbar_drag_start_top_row = start_top_row;
        self.tui_scrollbar_drag_start_thumb = start_thumb;
    }

    pub fn stop_tui_scrollbar_drag(&mut self) {
        self.tui_scrollbar_drag_active = false;
        self.tui_scrollbar_drag_start_y = 0;
        self.tui_scrollbar_drag_start_top_row = 0;
        self.tui_scrollbar_drag_start_thumb = 0;
    }

    pub fn is_tui_scrollbar_dragging(&self) -> bool {
        self.tui_scrollbar_drag_active
    }

    pub fn tui_scrollbar_drag_origin(&self) -> Option<(i32, i32, i32)> {
        self.tui_scrollbar_drag_active.then_some((
            self.tui_scrollbar_drag_start_y,
            self.tui_scrollbar_drag_start_top_row,
            self.tui_scrollbar_drag_start_thumb,
        ))
    }

    pub fn drain_input(&mut self, bytes: &[u8]) -> Vec<TerminalEvent> {
        let Some(viewport) = self.viewport else {
            self.parser.push_bytes(bytes);
            return Vec::new();
        };

        self.parser
            .push_bytes(bytes)
            .into_iter()
            .filter_map(|event| match event {
                ParsedTerminalEvent::Key {
                    key_code,
                    modifiers,
                    character,
                } => Some(TerminalEvent::Key(pb::KeyEvent {
                    r#type: pb::key_event::Type::KeyDown as i32,
                    key_code,
                    modifier: modifiers,
                    character: character.map(|ch| ch.to_string()).unwrap_or_default(),
                })),
                ParsedTerminalEvent::Pointer {
                    point,
                    event_type,
                    button,
                } => translate_pointer_event(viewport, point).map(|(x, y)| {
                    TerminalEvent::Pointer(pb::PointerEvent {
                        r#type: event_type,
                        x,
                        y,
                        modifier: point.modifiers,
                        button,
                        dbl_click: false,
                    })
                }),
                ParsedTerminalEvent::Scroll {
                    point,
                    delta_x,
                    delta_y,
                } => {
                    if translate_pointer_event(viewport, point).is_some() {
                        Some(TerminalEvent::Scroll(pb::ScrollEvent {
                            delta_x: delta_x as f32,
                            delta_y: delta_y as f32,
                        }))
                    } else {
                        None
                    }
                }
            })
            .flat_map(expand_key_event)
            .collect()
    }

    pub fn auto_start_edit_enabled(&self) -> bool {
        self.auto_start_edit
    }

    pub fn ensure_compose_default(&mut self, enabled: bool) {
        if self.compose_initialized {
            return;
        }
        self.compose_enabled = enabled;
        self.compose_initialized = true;
    }

    pub fn compose_enabled(&self) -> bool {
        self.compose_enabled
    }

    pub fn apply_navigation_edit_policy(
        &mut self,
        key: &pb::KeyEvent,
        editing: bool,
    ) -> TerminalKeyPolicyDecision {
        if key.key_code == 32 && key.modifier == 2 {
            if key.r#type == pb::key_event::Type::KeyDown as i32 {
                self.compose_enabled = !self.compose_enabled;
                self.compose_initialized = true;
            }
            return TerminalKeyPolicyDecision::ToggleCompose {
                enabled: self.compose_enabled,
            };
        }

        if editing {
            return TerminalKeyPolicyDecision::Forward;
        }

        if key.key_code == 45 && key.modifier == 0 {
            if key.r#type == pb::key_event::Type::KeyDown as i32 {
                self.auto_start_edit = !self.auto_start_edit;
            }
            return TerminalKeyPolicyDecision::Consume;
        }

        if self.auto_start_edit {
            return TerminalKeyPolicyDecision::Forward;
        }

        if key.r#type != pb::key_event::Type::KeyPress as i32 {
            return TerminalKeyPolicyDecision::Forward;
        }

        let Some(ch) = key.character.chars().next() else {
            return TerminalKeyPolicyDecision::Forward;
        };
        if ch == 'i' && key.modifier == 0 {
            return TerminalKeyPolicyDecision::StartEdit { caret_end: false };
        }
        if key.modifier == 0 {
            if let Some(key_code) = vim_navigation_key_code(ch) {
                return TerminalKeyPolicyDecision::RemapKeyDown {
                    key_code,
                    modifier: 0,
                };
            }
        }
        if ch >= ' ' {
            return TerminalKeyPolicyDecision::Consume;
        }
        TerminalKeyPolicyDecision::Forward
    }

    pub fn prepare_frame(
        &mut self,
        grid: &mut VolvoxGrid,
        renderer: &mut TuiRenderer,
        buffer_ready: &pb::BufferReady,
    ) -> PreparedTerminalFrame {
        let viewport = self
            .viewport
            .or_else(|| {
                if buffer_ready.width > 0 && buffer_ready.height > 0 {
                    Some(TerminalViewportState {
                        width: buffer_ready.width,
                        height: buffer_ready.height,
                        ..TerminalViewportState::default()
                    })
                } else {
                    None
                }
            })
            .unwrap_or_default();

        if viewport.width <= 0 || viewport.height <= 0 {
            return PreparedTerminalFrame {
                bytes: Vec::new(),
                rendered: false,
                frame_kind: pb::FrameKind::Frame as i32,
                required_capacity: 0,
                commit: Some(TerminalCommit {
                    session_started: self.session_started,
                    previous_cells: self.previous_cells.clone(),
                    previous_viewport: Some(viewport),
                    pending_shutdown: self.pending_shutdown,
                    force_full_repaint: true,
                }),
            };
        }

        let mut bytes = Vec::new();
        let mut frame_kind = pb::FrameKind::Frame as i32;
        let mut next_session_started = self.session_started;
        let mut next_pending_shutdown = self.pending_shutdown;
        let mut next_force_full_repaint = self.force_full_repaint;

        if self.pending_shutdown {
            append_shutdown_sequences(&mut bytes, self.capabilities, viewport.fullscreen);
            frame_kind = pb::FrameKind::SessionEnd as i32;
            next_session_started = false;
            next_pending_shutdown = false;
            next_force_full_repaint = true;
            return PreparedTerminalFrame {
                required_capacity: bytes.len(),
                bytes,
                rendered: false,
                frame_kind,
                commit: Some(TerminalCommit {
                    session_started: next_session_started,
                    previous_cells: Vec::new(),
                    previous_viewport: Some(viewport),
                    pending_shutdown: next_pending_shutdown,
                    force_full_repaint: next_force_full_repaint,
                }),
            };
        }

        if !self.session_started {
            append_start_sequences(&mut bytes, self.capabilities, viewport.fullscreen);
            frame_kind = pb::FrameKind::SessionStart as i32;
            next_session_started = true;
        }

        ensure_cell_buffer(&mut self.cells, viewport.width, viewport.height);
        let _ = renderer.render(
            grid,
            &mut self.cells,
            viewport.width,
            viewport.height,
            viewport.width as usize,
        );

        let render_needed = self.force_full_repaint
            || self.previous_viewport != Some(viewport)
            || self.previous_cells.len() != self.cells.len();

        if self.force_full_repaint {
            if let Some(previous) = self.previous_viewport {
                if previous != viewport {
                    encode_clear_rect(
                        &mut bytes,
                        previous,
                        TerminalStyle {
                            fg: TUI_COLOR_RESET,
                            bg: TUI_COLOR_RESET,
                            attr: 0,
                        },
                        effective_color_level(self.capabilities.color_level),
                    );
                }
            }
        }

        let rendered = encode_diff(
            &mut bytes,
            &self.cells,
            if render_needed {
                None
            } else {
                Some(self.previous_cells.as_slice())
            },
            viewport,
            effective_color_level(self.capabilities.color_level),
            self.force_full_repaint,
        );

        if rendered {
            bytes.extend_from_slice(b"\x1b[0m");
            next_force_full_repaint = false;
        }

        PreparedTerminalFrame {
            required_capacity: bytes.len(),
            bytes,
            rendered,
            frame_kind,
            commit: Some(TerminalCommit {
                session_started: next_session_started,
                previous_cells: self.cells.clone(),
                previous_viewport: Some(viewport),
                pending_shutdown: next_pending_shutdown,
                force_full_repaint: next_force_full_repaint,
            }),
        }
    }
}

fn ensure_cell_buffer(buffer: &mut Vec<TuiCell>, width: i32, height: i32) {
    let needed = (width.max(0) as usize).saturating_mul(height.max(0) as usize);
    if buffer.len() != needed {
        buffer.resize(needed, TuiCell::default());
    }
}

fn translate_pointer_event(
    viewport: TerminalViewportState,
    point: MousePoint,
) -> Option<(f32, f32)> {
    let local_x = point.x - viewport.origin_x;
    let local_y = point.y - viewport.origin_y;
    if local_x < 0 || local_y < 0 || local_x >= viewport.width || local_y >= viewport.height {
        return None;
    }
    Some((local_x as f32, local_y as f32))
}

fn vim_navigation_key_code(ch: char) -> Option<i32> {
    match ch {
        'h' => Some(37),
        'j' => Some(40),
        'k' => Some(38),
        'l' => Some(39),
        _ => None,
    }
}

fn expand_key_event(event: TerminalEvent) -> Vec<TerminalEvent> {
    match event {
        TerminalEvent::Key(key) => {
            let mut outputs = Vec::with_capacity(3);
            outputs.push(TerminalEvent::Key(pb::KeyEvent {
                r#type: pb::key_event::Type::KeyDown as i32,
                key_code: key.key_code,
                modifier: key.modifier,
                character: String::new(),
            }));
            if !key.character.is_empty() {
                outputs.push(TerminalEvent::Key(pb::KeyEvent {
                    r#type: pb::key_event::Type::KeyPress as i32,
                    key_code: key.key_code,
                    modifier: key.modifier,
                    character: key.character.clone(),
                }));
            }
            outputs.push(TerminalEvent::Key(pb::KeyEvent {
                r#type: pb::key_event::Type::KeyUp as i32,
                key_code: key.key_code,
                modifier: key.modifier,
                character: String::new(),
            }));
            outputs
        }
        other => vec![other],
    }
}

impl TerminalInputParser {
    fn push_bytes(&mut self, bytes: &[u8]) -> Vec<ParsedTerminalEvent> {
        if !bytes.is_empty() {
            self.pending.extend_from_slice(bytes);
        }

        let mut outputs = Vec::new();
        loop {
            if self.paste_mode {
                if let Some(end) = find_bytes(&self.pending, b"\x1b[201~") {
                    self.paste_buffer.extend_from_slice(&self.pending[..end]);
                    self.pending.drain(..end + 6);
                    let text = String::from_utf8_lossy(&self.paste_buffer).into_owned();
                    self.paste_buffer.clear();
                    self.paste_mode = false;
                    for ch in text.chars() {
                        outputs.push(ParsedTerminalEvent::Key {
                            key_code: key_code_for_char(ch),
                            modifiers: 0,
                            character: Some(ch),
                        });
                    }
                    continue;
                }

                self.paste_buffer.extend_from_slice(&self.pending);
                self.pending.clear();
                break;
            }

            if self.pending.starts_with(b"\x1b[200~") {
                self.pending.drain(..6);
                self.paste_mode = true;
                continue;
            }

            let Some((event, consumed)) = self.try_parse_next() else {
                break;
            };
            self.pending.drain(..consumed);
            if let Some(event) = event {
                outputs.push(event);
            }
        }
        outputs
    }

    fn try_parse_next(&self) -> Option<(Option<ParsedTerminalEvent>, usize)> {
        let first = *self.pending.first()?;
        if first != 0x1B {
            return parse_plain_key(&self.pending);
        }

        if self.pending.len() == 1 {
            return Some((
                Some(ParsedTerminalEvent::Key {
                    key_code: 27,
                    modifiers: 0,
                    character: None,
                }),
                1,
            ));
        }

        if self.pending[1] == b'O' {
            return parse_ss3_key(&self.pending);
        }

        if self.pending[1] != b'[' {
            let (event, consumed) = parse_plain_key(&self.pending[1..])?;
            let event = event.map(|parsed| match parsed {
                ParsedTerminalEvent::Key {
                    key_code,
                    modifiers,
                    character,
                } => ParsedTerminalEvent::Key {
                    key_code,
                    modifiers: modifiers | 4,
                    character,
                },
                other => other,
            });
            return Some((event, consumed + 1));
        }

        if self.pending.len() >= 3 && self.pending[2] == b'<' {
            return parse_sgr_mouse(&self.pending);
        }

        if self.pending.len() >= 3 && self.pending[2] == b'I' {
            return Some((None, 3));
        }
        if self.pending.len() >= 3 && self.pending[2] == b'O' {
            return Some((None, 3));
        }

        parse_csi_key(&self.pending)
    }
}

fn parse_plain_key(bytes: &[u8]) -> Option<(Option<ParsedTerminalEvent>, usize)> {
    let first = *bytes.first()?;
    match first {
        0x7F => Some((
            Some(ParsedTerminalEvent::Key {
                key_code: 8,
                modifiers: 0,
                character: None,
            }),
            1,
        )),
        0x09 => Some((
            Some(ParsedTerminalEvent::Key {
                key_code: 9,
                modifiers: 0,
                character: None,
            }),
            1,
        )),
        0x0D | 0x0A => Some((
            Some(ParsedTerminalEvent::Key {
                key_code: 13,
                modifiers: 0,
                character: None,
            }),
            1,
        )),
        0x03 => Some((
            Some(ParsedTerminalEvent::Key {
                key_code: 'C' as i32,
                modifiers: 2,
                character: Some('c'),
            }),
            1,
        )),
        1..=26 => {
            let ch = char::from_u32('A' as u32 + (first as u32 - 1)).unwrap_or('A');
            Some((
                Some(ParsedTerminalEvent::Key {
                    key_code: ch as i32,
                    modifiers: 2,
                    character: Some(ch),
                }),
                1,
            ))
        }
        32..=126 => {
            let ch = first as char;
            Some((
                Some(ParsedTerminalEvent::Key {
                    key_code: key_code_for_char(ch),
                    modifiers: 0,
                    character: Some(ch),
                }),
                1,
            ))
        }
        _ => decode_utf8_char(bytes).map(|(ch, consumed)| {
            (
                Some(ParsedTerminalEvent::Key {
                    key_code: key_code_for_char(ch),
                    modifiers: 0,
                    character: Some(ch),
                }),
                consumed,
            )
        }),
    }
}

fn decode_utf8_char(bytes: &[u8]) -> Option<(char, usize)> {
    let first = *bytes.first()?;
    let needed = match first {
        0xC2..=0xDF => 2,
        0xE0..=0xEF => 3,
        0xF0..=0xF4 => 4,
        _ => return None,
    };
    if bytes.len() < needed {
        return None;
    }
    let text = std::str::from_utf8(&bytes[..needed]).ok()?;
    let ch = text.chars().next()?;
    Some((ch, needed))
}

fn parse_sgr_mouse(bytes: &[u8]) -> Option<(Option<ParsedTerminalEvent>, usize)> {
    let mut end = None;
    for (index, value) in bytes.iter().enumerate().skip(3) {
        if *value == b'M' || *value == b'm' {
            end = Some(index);
            break;
        }
    }
    let end = end?;
    let terminator = bytes[end];
    let payload = std::str::from_utf8(&bytes[3..end]).ok()?;
    let mut parts = payload.split(';');
    let code: i32 = parts.next()?.parse().ok()?;
    let x: i32 = parts.next()?.parse().ok()?;
    let y: i32 = parts.next()?.parse().ok()?;
    let point = MousePoint {
        x: (x - 1).max(0),
        y: (y - 1).max(0),
        modifiers: mouse_modifier_bits(code),
    };

    if (code & 64) != 0 {
        let event = match code & 3 {
            0 => ParsedTerminalEvent::Scroll {
                point,
                delta_x: 0,
                delta_y: -1,
            },
            1 => ParsedTerminalEvent::Scroll {
                point,
                delta_x: 0,
                delta_y: 1,
            },
            2 => ParsedTerminalEvent::Scroll {
                point,
                delta_x: -1,
                delta_y: 0,
            },
            _ => ParsedTerminalEvent::Scroll {
                point,
                delta_x: 1,
                delta_y: 0,
            },
        };
        return Some((Some(event), end + 1));
    }

    let base_button = code & 3;
    let motion = (code & 32) != 0;
    let event = if terminator == b'm' {
        ParsedTerminalEvent::Pointer {
            point,
            event_type: pb::pointer_event::Type::Up as i32,
            button: decode_mouse_button(base_button),
        }
    } else if motion {
        ParsedTerminalEvent::Pointer {
            point,
            event_type: pb::pointer_event::Type::Move as i32,
            button: decode_mouse_drag_mask(base_button),
        }
    } else {
        ParsedTerminalEvent::Pointer {
            point,
            event_type: pb::pointer_event::Type::Down as i32,
            button: decode_mouse_button(base_button),
        }
    };
    Some((Some(event), end + 1))
}

fn parse_ss3_key(bytes: &[u8]) -> Option<(Option<ParsedTerminalEvent>, usize)> {
    if bytes.len() < 3 {
        return None;
    }

    let event = match bytes[2] as char {
        'P' => Some(simple_key_event(112, 0)),
        'Q' => Some(simple_key_event(113, 0)),
        'R' => Some(simple_key_event(114, 0)),
        'S' => Some(simple_key_event(115, 0)),
        'A' => Some(simple_key_event(38, 0)),
        'B' => Some(simple_key_event(40, 0)),
        'C' => Some(simple_key_event(39, 0)),
        'D' => Some(simple_key_event(37, 0)),
        'F' => Some(simple_key_event(35, 0)),
        'H' => Some(simple_key_event(36, 0)),
        _ => None,
    };
    Some((event.map(Some).unwrap_or(None), 3))
}

fn parse_csi_key(bytes: &[u8]) -> Option<(Option<ParsedTerminalEvent>, usize)> {
    let mut index = 2;
    while index < bytes.len() {
        let value = bytes[index];
        if value.is_ascii_alphabetic() || value == b'~' {
            break;
        }
        index += 1;
    }
    if index >= bytes.len() {
        return None;
    }

    let final_char = bytes[index] as char;
    let payload = std::str::from_utf8(&bytes[2..index]).ok()?;
    let modifiers = parse_csi_modifiers(payload);
    let event = match final_char {
        'A' => Some(simple_key_event(38, modifiers)),
        'B' => Some(simple_key_event(40, modifiers)),
        'C' => Some(simple_key_event(39, modifiers)),
        'D' => Some(simple_key_event(37, modifiers)),
        'H' => Some(simple_key_event(36, modifiers)),
        'F' => Some(simple_key_event(35, modifiers)),
        'P' => Some(simple_key_event(112, modifiers)),
        'Q' => Some(simple_key_event(113, modifiers)),
        'R' => Some(simple_key_event(114, modifiers)),
        'S' => Some(simple_key_event(115, modifiers)),
        'Z' => Some(simple_key_event(9, modifiers | 1)),
        '~' => parse_csi_tilde_key(payload).map(|key_code| simple_key_event(key_code, modifiers)),
        _ => None,
    };
    Some((event.map(Some).unwrap_or(None), index + 1))
}

fn simple_key_event(key_code: i32, modifiers: i32) -> ParsedTerminalEvent {
    ParsedTerminalEvent::Key {
        key_code,
        modifiers,
        character: None,
    }
}

fn parse_csi_tilde_key(payload: &str) -> Option<i32> {
    let first = payload.split(';').next()?.parse::<i32>().ok()?;
    match first {
        1 | 7 => Some(36),
        2 => Some(45),
        3 => Some(46),
        4 | 8 => Some(35),
        5 => Some(33),
        6 => Some(34),
        11 => Some(112),
        12 => Some(113),
        13 => Some(114),
        14 => Some(115),
        15 => Some(116),
        17 => Some(117),
        18 => Some(118),
        19 => Some(119),
        20 => Some(120),
        21 => Some(121),
        23 => Some(122),
        24 => Some(123),
        _ => None,
    }
}

fn parse_csi_modifiers(payload: &str) -> i32 {
    let parts: Vec<&str> = payload.split(';').collect();
    if parts.len() < 2 {
        return 0;
    }
    let encoded = parts
        .last()
        .and_then(|value| value.parse::<i32>().ok())
        .unwrap_or(1);
    let xterm_bits = cmp::max(0, encoded - 1);
    let mut modifiers = 0;
    if (xterm_bits & 1) != 0 {
        modifiers |= 1;
    }
    if (xterm_bits & 4) != 0 {
        modifiers |= 2;
    }
    if (xterm_bits & 2) != 0 {
        modifiers |= 4;
    }
    modifiers
}

fn mouse_modifier_bits(code: i32) -> i32 {
    let mut modifiers = 0;
    if (code & 4) != 0 {
        modifiers |= 1;
    }
    if (code & 8) != 0 {
        modifiers |= 4;
    }
    if (code & 16) != 0 {
        modifiers |= 2;
    }
    modifiers
}

fn decode_mouse_button(base_button: i32) -> i32 {
    match base_button {
        0 => 0,
        1 => 2,
        2 => 1,
        _ => 0,
    }
}

fn decode_mouse_drag_mask(base_button: i32) -> i32 {
    match base_button {
        0 => 1,
        1 => 4,
        2 => 2,
        _ => 0,
    }
}

fn key_code_for_char(ch: char) -> i32 {
    if ch.is_ascii() {
        ch.to_ascii_uppercase() as i32
    } else {
        ch as i32
    }
}

fn find_bytes(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    if needle.is_empty() || haystack.len() < needle.len() {
        return None;
    }
    haystack
        .windows(needle.len())
        .position(|window| window == needle)
}

fn append_start_sequences(bytes: &mut Vec<u8>, caps: TerminalCapabilitiesState, fullscreen: bool) {
    if fullscreen {
        bytes.extend_from_slice(b"\x1b[?1049h\x1b[2J\x1b[H");
    }
    bytes.extend_from_slice(b"\x1b[?25l");
    if caps.sgr_mouse {
        bytes.extend_from_slice(b"\x1b[?1000h\x1b[?1002h\x1b[?1006h");
    }
    if caps.focus_events {
        bytes.extend_from_slice(b"\x1b[?1004h");
    }
    if caps.bracketed_paste {
        bytes.extend_from_slice(b"\x1b[?2004h");
    }
}

fn append_shutdown_sequences(
    bytes: &mut Vec<u8>,
    caps: TerminalCapabilitiesState,
    fullscreen: bool,
) {
    if caps.bracketed_paste {
        bytes.extend_from_slice(b"\x1b[?2004l");
    }
    if caps.focus_events {
        bytes.extend_from_slice(b"\x1b[?1004l");
    }
    if caps.sgr_mouse {
        bytes.extend_from_slice(b"\x1b[?1006l\x1b[?1002l\x1b[?1000l");
    }
    bytes.extend_from_slice(b"\x1b[0m\x1b[?25h");
    if fullscreen {
        bytes.extend_from_slice(b"\x1b[?1049l");
    }
}

fn encode_diff(
    bytes: &mut Vec<u8>,
    current: &[TuiCell],
    previous: Option<&[TuiCell]>,
    viewport: TerminalViewportState,
    color_level: i32,
    force_full_repaint: bool,
) -> bool {
    let width = viewport.width.max(0) as usize;
    let height = viewport.height.max(0) as usize;
    if width == 0 || height == 0 {
        return false;
    }

    let mut rendered = false;
    let mut style = None;

    for row in 0..height {
        let row_start = row * width;
        let row_end = row_start + width;
        let current_row = &current[row_start..row_end];
        let changed_range = if force_full_repaint {
            Some((0usize, width))
        } else {
            previous.and_then(|prev| diff_range(current_row, &prev[row_start..row_end]))
        };
        let Some((start, end)) = changed_range else {
            continue;
        };
        rendered = true;
        cursor_to(
            bytes,
            viewport.origin_y + row as i32,
            viewport.origin_x + start as i32,
        );
        for cell in &current_row[start..end] {
            let next_style = TerminalStyle {
                fg: cell.fg,
                bg: cell.bg,
                attr: cell.attr,
            };
            if style != Some(next_style) {
                push_style(bytes, next_style, color_level);
                style = Some(next_style);
            }
            if cell.is_continuation() {
                continue;
            }
            bytes.extend_from_slice(
                sanitize_terminal_char(cell.ch())
                    .encode_utf8(&mut [0; 4])
                    .as_bytes(),
            );
        }
    }

    rendered
}

fn diff_range(current: &[TuiCell], previous: &[TuiCell]) -> Option<(usize, usize)> {
    let mut start = None;
    let mut end = 0usize;
    for (index, (lhs, rhs)) in current.iter().zip(previous.iter()).enumerate() {
        if lhs != rhs {
            start.get_or_insert(index);
            end = index + 1;
        }
    }
    start.map(|start| (start, end))
}

fn encode_clear_rect(
    bytes: &mut Vec<u8>,
    viewport: TerminalViewportState,
    style: TerminalStyle,
    color_level: i32,
) {
    if viewport.width <= 0 || viewport.height <= 0 {
        return;
    }
    let mut emitted_style = false;
    for row in 0..viewport.height {
        cursor_to(bytes, viewport.origin_y + row, viewport.origin_x);
        if !emitted_style {
            push_style(bytes, style, color_level);
            emitted_style = true;
        }
        for _ in 0..viewport.width {
            bytes.push(b' ');
        }
    }
}

fn cursor_to(bytes: &mut Vec<u8>, row: i32, col: i32) {
    let row = row.max(0) + 1;
    let col = col.max(0) + 1;
    bytes.extend_from_slice(b"\x1b[");
    bytes.extend_from_slice(row.to_string().as_bytes());
    bytes.push(b';');
    bytes.extend_from_slice(col.to_string().as_bytes());
    bytes.push(b'H');
}

fn push_style(bytes: &mut Vec<u8>, style: TerminalStyle, color_level: i32) {
    bytes.extend_from_slice(b"\x1b[0");
    if style.attr & TUI_ATTR_BOLD != 0 {
        bytes.extend_from_slice(b";1");
    }
    if style.attr & TUI_ATTR_ITALIC != 0 {
        bytes.extend_from_slice(b";3");
    }
    if style.attr & TUI_ATTR_UNDERLINE != 0 {
        bytes.extend_from_slice(b";4");
    }
    if style.attr & TUI_ATTR_REVERSE != 0 {
        bytes.extend_from_slice(b";7");
    }
    append_color(bytes, style.fg, false, color_level);
    append_color(bytes, style.bg, true, color_level);
    bytes.push(b'm');
}

fn append_color(bytes: &mut Vec<u8>, rgb: u32, background: bool, color_level: i32) {
    if rgb == TUI_COLOR_RESET {
        bytes.extend_from_slice(if background { b";49" } else { b";39" });
        return;
    }
    match color_level {
        x if x == pb::TerminalColorLevel::TerminalColorLevel16 as i32 => {
            let index = quantize_ansi16(rgb);
            let base = if background {
                if index < 8 {
                    40
                } else {
                    100
                }
            } else if index < 8 {
                30
            } else {
                90
            };
            let code = base + (index % 8) as i32;
            bytes.extend_from_slice(b";");
            bytes.extend_from_slice(code.to_string().as_bytes());
        }
        x if x == pb::TerminalColorLevel::TerminalColorLevel256 as i32 => {
            let code = quantize_ansi256(rgb);
            bytes.extend_from_slice(if background { b";48;5;" } else { b";38;5;" });
            bytes.extend_from_slice(code.to_string().as_bytes());
        }
        _ => {
            let r = ((rgb >> 16) & 0xFF) as u8;
            let g = ((rgb >> 8) & 0xFF) as u8;
            let b = (rgb & 0xFF) as u8;
            bytes.extend_from_slice(if background { b";48;2;" } else { b";38;2;" });
            bytes.extend_from_slice(r.to_string().as_bytes());
            bytes.push(b';');
            bytes.extend_from_slice(g.to_string().as_bytes());
            bytes.push(b';');
            bytes.extend_from_slice(b.to_string().as_bytes());
        }
    }
}

fn quantize_ansi256(rgb: u32) -> u8 {
    let r = ((rgb >> 16) & 0xFF) as i32;
    let g = ((rgb >> 8) & 0xFF) as i32;
    let b = (rgb & 0xFF) as i32;

    if r == g && g == b {
        if r < 8 {
            return 16;
        }
        if r > 248 {
            return 231;
        }
        return (((r - 8) / 10) + 232) as u8;
    }

    let r = ((r * 5 + 127) / 255) as u8;
    let g = ((g * 5 + 127) / 255) as u8;
    let b = ((b * 5 + 127) / 255) as u8;
    16 + 36 * r + 6 * g + b
}

fn quantize_ansi16(rgb: u32) -> usize {
    const ANSI16: [(i32, i32, i32); 16] = [
        (0, 0, 0),
        (205, 0, 0),
        (0, 205, 0),
        (205, 205, 0),
        (0, 0, 238),
        (205, 0, 205),
        (0, 205, 205),
        (229, 229, 229),
        (127, 127, 127),
        (255, 0, 0),
        (0, 255, 0),
        (255, 255, 0),
        (92, 92, 255),
        (255, 0, 255),
        (0, 255, 255),
        (255, 255, 255),
    ];

    let r = ((rgb >> 16) & 0xFF) as i32;
    let g = ((rgb >> 8) & 0xFF) as i32;
    let b = (rgb & 0xFF) as i32;
    let mut best_index = 0usize;
    let mut best_distance = i64::MAX;
    for (index, (pr, pg, pb)) in ANSI16.iter().enumerate() {
        let dr = i64::from(r - pr);
        let dg = i64::from(g - pg);
        let db = i64::from(b - pb);
        let distance = dr * dr + dg * dg + db * db;
        if distance < best_distance {
            best_distance = distance;
            best_index = index;
        }
    }
    best_index
}

fn effective_color_level(color_level: i32) -> i32 {
    if color_level == pb::TerminalColorLevel::Auto as i32 {
        pb::TerminalColorLevel::Truecolor as i32
    } else {
        color_level
    }
}

fn sanitize_terminal_char(ch: char) -> char {
    if ch.is_control() {
        ' '
    } else {
        ch
    }
}

#[cfg(test)]
mod tests {
    use super::{
        append_color, diff_range, encode_diff, parse_csi_key, parse_plain_key, parse_sgr_mouse,
        quantize_ansi16, quantize_ansi256, TerminalInputParser, TerminalKeyPolicyDecision,
        TerminalStyle, TerminalTuiSession, TerminalViewportState,
    };
    use volvoxgrid_engine::canvas_tui::TuiCell;
    use volvoxgrid_engine::proto::volvoxgrid::v1 as pb;

    #[test]
    fn parser_decodes_ascii_char() {
        let (event, consumed) = parse_plain_key(b"a").expect("plain key");
        assert_eq!(consumed, 1);
        let event = event.expect("event");
        match event {
            super::ParsedTerminalEvent::Key {
                key_code,
                modifiers,
                character,
            } => {
                assert_eq!(key_code, 'A' as i32);
                assert_eq!(modifiers, 0);
                assert_eq!(character, Some('a'));
            }
            _ => panic!("expected key"),
        }
    }

    #[test]
    fn parser_decodes_arrow_key() {
        let (event, consumed) = parse_csi_key(b"\x1b[A").expect("csi key");
        assert_eq!(consumed, 3);
        let event = event.expect("event");
        match event {
            super::ParsedTerminalEvent::Key { key_code, .. } => assert_eq!(key_code, 38),
            _ => panic!("expected key"),
        }
    }

    #[test]
    fn parser_decodes_ss3_arrow_key() {
        let mut parser = TerminalInputParser::default();
        let events = parser.push_bytes(b"\x1bOB");
        assert_eq!(events.len(), 1);
        match &events[0] {
            super::ParsedTerminalEvent::Key { key_code, .. } => assert_eq!(*key_code, 40),
            _ => panic!("expected key"),
        }
    }

    #[test]
    fn parser_decodes_function_keys() {
        let (event, consumed) = parse_csi_key(b"\x1b[12~").expect("f2 key");
        assert_eq!(consumed, 5);
        let event = event.expect("event");
        match event {
            super::ParsedTerminalEvent::Key { key_code, .. } => assert_eq!(key_code, 113),
            _ => panic!("expected key"),
        }

        let (event, consumed) = parse_csi_key(b"\x1b[17~").expect("f6 key");
        assert_eq!(consumed, 5);
        let event = event.expect("event");
        match event {
            super::ParsedTerminalEvent::Key { key_code, .. } => assert_eq!(key_code, 117),
            _ => panic!("expected key"),
        }

        let mut parser = TerminalInputParser::default();
        let events = parser.push_bytes(b"\x1bOQ");
        assert_eq!(events.len(), 1);
        match &events[0] {
            super::ParsedTerminalEvent::Key { key_code, .. } => assert_eq!(*key_code, 113),
            _ => panic!("expected key"),
        }
    }

    #[test]
    fn parser_decodes_sgr_mouse_scroll() {
        let (event, consumed) = parse_sgr_mouse(b"\x1b[<64;10;5M").expect("mouse");
        assert_eq!(consumed, 11);
        let event = event.expect("event");
        match event {
            super::ParsedTerminalEvent::Scroll {
                delta_x,
                delta_y,
                point,
            } => {
                assert_eq!(delta_x, 0);
                assert_eq!(delta_y, -1);
                assert_eq!(point.x, 9);
                assert_eq!(point.y, 4);
            }
            _ => panic!("expected scroll"),
        }
    }

    #[test]
    fn parser_decodes_bracketed_paste() {
        let mut parser = TerminalInputParser::default();
        let events = parser.push_bytes(b"\x1b[200~ab\x1b[201~");
        assert_eq!(events.len(), 2);
    }

    #[test]
    fn navigation_policy_toggles_auto_start_on_insert() {
        let mut session = TerminalTuiSession::new();
        let decision = session.apply_navigation_edit_policy(
            &pb::KeyEvent {
                r#type: pb::key_event::Type::KeyDown as i32,
                key_code: 45,
                modifier: 0,
                character: String::new(),
            },
            false,
        );
        assert_eq!(decision, TerminalKeyPolicyDecision::Consume);
        assert!(session.auto_start_edit_enabled());
    }

    #[test]
    fn navigation_policy_consumes_printable_text_until_auto_start_enabled() {
        let mut session = TerminalTuiSession::new();
        let decision = session.apply_navigation_edit_policy(
            &pb::KeyEvent {
                r#type: pb::key_event::Type::KeyPress as i32,
                key_code: 'X' as i32,
                modifier: 0,
                character: "x".to_string(),
            },
            false,
        );
        assert_eq!(decision, TerminalKeyPolicyDecision::Consume);
        assert!(!session.auto_start_edit_enabled());
    }

    #[test]
    fn navigation_policy_uses_i_for_explicit_edit() {
        let mut session = TerminalTuiSession::new();
        let decision = session.apply_navigation_edit_policy(
            &pb::KeyEvent {
                r#type: pb::key_event::Type::KeyPress as i32,
                key_code: 'I' as i32,
                modifier: 0,
                character: "i".to_string(),
            },
            false,
        );
        assert_eq!(
            decision,
            TerminalKeyPolicyDecision::StartEdit { caret_end: false }
        );
    }

    #[test]
    fn navigation_policy_toggles_compose_on_ctrl_space() {
        let mut session = TerminalTuiSession::new();
        session.ensure_compose_default(true);
        let decision = session.apply_navigation_edit_policy(
            &pb::KeyEvent {
                r#type: pb::key_event::Type::KeyDown as i32,
                key_code: 32,
                modifier: 2,
                character: String::new(),
            },
            false,
        );
        assert_eq!(
            decision,
            TerminalKeyPolicyDecision::ToggleCompose { enabled: false }
        );
        assert!(!session.compose_enabled());
    }

    #[test]
    fn navigation_policy_remaps_hjkl_to_arrow_keys() {
        let mut session = TerminalTuiSession::new();
        for (ch, key_code) in [('h', 37), ('j', 40), ('k', 38), ('l', 39)] {
            let decision = session.apply_navigation_edit_policy(
                &pb::KeyEvent {
                    r#type: pb::key_event::Type::KeyPress as i32,
                    key_code: ch as i32,
                    modifier: 0,
                    character: ch.to_string(),
                },
                false,
            );
            assert_eq!(
                decision,
                TerminalKeyPolicyDecision::RemapKeyDown {
                    key_code,
                    modifier: 0,
                }
            );
        }
    }

    #[test]
    fn navigation_policy_forwards_printable_text_when_auto_start_enabled() {
        let mut session = TerminalTuiSession::new();
        let _ = session.apply_navigation_edit_policy(
            &pb::KeyEvent {
                r#type: pb::key_event::Type::KeyDown as i32,
                key_code: 45,
                modifier: 0,
                character: String::new(),
            },
            false,
        );
        let decision = session.apply_navigation_edit_policy(
            &pb::KeyEvent {
                r#type: pb::key_event::Type::KeyPress as i32,
                key_code: 'X' as i32,
                modifier: 0,
                character: "x".to_string(),
            },
            false,
        );
        assert_eq!(decision, TerminalKeyPolicyDecision::Forward);
    }

    #[test]
    fn diff_range_tracks_changed_segment() {
        let before = vec![
            TuiCell::new('a', 0, 0, 0),
            TuiCell::new('b', 0, 0, 0),
            TuiCell::new('c', 0, 0, 0),
        ];
        let after = vec![
            TuiCell::new('a', 0, 0, 0),
            TuiCell::new('x', 0, 0, 0),
            TuiCell::new('c', 0, 0, 0),
        ];
        assert_eq!(diff_range(&after, &before), Some((1, 2)));
    }

    #[test]
    fn encode_diff_skips_continuation_cells() {
        let current = vec![
            TuiCell::new('가', 0, 0, 0),
            TuiCell::continuation(0, 0, 0),
            TuiCell::new('X', 0, 0, 0),
        ];
        let mut bytes = Vec::new();
        let rendered = encode_diff(
            &mut bytes,
            &current,
            None,
            TerminalViewportState {
                origin_x: 0,
                origin_y: 0,
                width: 3,
                height: 1,
                fullscreen: false,
            },
            pb::TerminalColorLevel::Truecolor as i32,
            true,
        );
        assert!(rendered);
        assert!(String::from_utf8(bytes).unwrap().ends_with("가X"));
    }

    #[test]
    fn ansi_quantizers_choose_expected_buckets() {
        assert_eq!(quantize_ansi256(0x00FF0000), 196);
        assert_eq!(quantize_ansi16(0x00FF0000), 9);
    }

    #[test]
    fn append_color_emits_truecolor_sequence() {
        let mut bytes = Vec::new();
        append_color(
            &mut bytes,
            0x00112233,
            false,
            pb::TerminalColorLevel::Truecolor as i32,
        );
        assert_eq!(String::from_utf8(bytes).unwrap(), ";38;2;17;34;51");
    }

    #[test]
    fn append_color_resets_default_color() {
        let mut bytes = Vec::new();
        append_color(
            &mut bytes,
            volvoxgrid_engine::canvas_tui::TUI_COLOR_RESET,
            true,
            pb::TerminalColorLevel::Truecolor as i32,
        );
        assert_eq!(String::from_utf8(bytes).unwrap(), ";49");
    }

    #[test]
    fn terminal_style_is_copyable() {
        let style = TerminalStyle {
            fg: 1,
            bg: 2,
            attr: 3,
        };
        assert_eq!(style, style);
    }
}
