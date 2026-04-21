mod ffi;
mod proto {
    pub mod volvoxgrid {
        pub mod v1 {
            include!(concat!(env!("OUT_DIR"), "/volvoxgrid.v1.rs"));
        }
    }
}

use std::cell::RefCell;
use std::collections::HashMap;
use std::os::unix::io::RawFd;
use std::rc::Rc;
use std::sync::{mpsc, Arc};
use std::time::Duration;

use cairo::ImageSurface;
use gtk4::gdk;
use gtk4::glib;
use gtk4::prelude::*;
use gtk4::{
    Align, Application, ApplicationWindow, Box as GtkBox, Button, CheckButton, ComboBoxText,
    CssProvider, DrawingArea, DropDown, Entry, EventControllerKey, EventControllerMotion,
    EventControllerScroll, GestureClick, Label, MenuButton, Orientation, Overlay, Popover,
    ScrolledWindow, Separator, SpinButton,
};
use prost::Message;
use serde::{Deserialize, Serialize};

use ffi::{resolve_default_plugin_path, PluginLibrary, PluginStream};
use proto::volvoxgrid::v1 as pb;

const APP_ID: &str = "io.github.ivere27.volvoxgrid.GtkTest";
const DEFAULT_WIDTH: i32 = 1280;
const DEFAULT_HEIGHT: i32 = 900;
const WHEEL_SCROLL_GAIN: f32 = 3.0;
const DEMO_STRESS: &str = "stress";
const DEMO_SALES: &str = "sales";
const DEMO_HIERARCHY: &str = "hierarchy";
const SALES_DEMO_COLS: i32 = 10;
const HIERARCHY_DEMO_COLS: i32 = 6;
const SALES_STATUS_ITEMS: &str = "Active|Pending|Shipped|Returned|Cancelled";
const SELECTION_MODE_LABELS: [&str; 5] = ["Free", "ByRow", "ByCol", "Listbox", "MultiRange"];
const FRAME_PACING_LABELS: [&str; 4] = ["Auto", "Platform", "Unlimited", "Fixed"];
const LAYER_COUNT: usize = 27;
const LAYER_LABELS: [&str; LAYER_COUNT] = [
    "Overlay Bands",
    "Indicators",
    "Backgrounds",
    "Progress Bars",
    "Grid Lines",
    "Header Marks",
    "Background Image",
    "Cell Borders",
    "Cell Text",
    "Cell Pictures",
    "Sort Glyphs",
    "Col Drag Marker",
    "Checkboxes",
    "Dropdown Buttons",
    "Selection",
    "Hover Highlight",
    "Edit Highlights",
    "Focus Rect",
    "Fill Handle",
    "Outline",
    "Frozen Borders",
    "Active Editor",
    "Active Dropdown",
    "Scroll Bars",
    "Fast Scroll",
    "Pull To Refresh",
    "Debug Overlay",
];
const INLINE_EDITOR_CSS: &str = r#"
entry.volvox-inline-editor,
entry.volvox-inline-editor text {
  background-color: #ffffff;
  color: #000000;
  caret-color: #000000;
  min-height: 0;
  min-width: 0;
  margin: 0;
  box-shadow: none;
}

entry.volvox-inline-editor {
  border: 1px solid #2d6cdf;
  border-radius: 0;
  box-shadow: none;
  padding: 0;
  margin: 0;
  min-height: 0;
  min-width: 0;
}

entry.volvox-inline-editor text {
  padding: 0 4px;
  border-radius: 0;
}

button.volvox-demo-active {
  background-image: none;
  background-color: #cce2ff;
  color: #173d74;
  font-weight: 700;
}

button.volvox-demo-active label {
  font-weight: 700;
}
"#;

#[derive(Debug, Deserialize)]
struct HierarchyJsonRow {
    #[serde(rename = "Name")]
    name: String,
    #[serde(rename = "Type")]
    kind: String,
    #[serde(rename = "Size")]
    size: String,
    #[serde(rename = "Modified")]
    modified: String,
    #[serde(rename = "Permissions")]
    permissions: String,
    #[serde(rename = "Action")]
    action: String,
    #[serde(rename = "_level")]
    level: i32,
}

#[derive(Serialize)]
struct HierarchyLoadRow<'a> {
    #[serde(rename = "Name")]
    name: &'a str,
    #[serde(rename = "Type")]
    kind: &'a str,
    #[serde(rename = "Size")]
    size: &'a str,
    #[serde(rename = "Modified")]
    modified: &'a str,
    #[serde(rename = "Permissions")]
    permissions: &'a str,
    #[serde(rename = "Action")]
    action: &'a str,
}

#[derive(Clone)]
struct VolvoxServiceClient {
    plugin: Arc<PluginLibrary>,
}

enum UiMessage {
    RenderOutput(u64, pb::RenderOutput),
    GridEvent(u64, pb::GridEvent),
    StreamEnded(u64, &'static str),
    StreamError(u64, &'static str, String),
}

#[derive(Clone)]
struct UiMessageSender {
    sender: mpsc::Sender<UiMessage>,
    wake_pipe: Arc<WakePipe>,
}

struct UiMessageReceiver {
    receiver: mpsc::Receiver<UiMessage>,
    wake_pipe: Arc<WakePipe>,
}

struct WakePipe {
    read_fd: RawFd,
    write_fd: RawFd,
}

struct FrameTarget {
    width: i32,
    height: i32,
    surface: ImageSurface,
    present_buffer: Box<[u8]>,
    render_buffer: Box<[u8]>,
}

impl FrameTarget {
    fn new(width: i32, height: i32) -> Result<Self, String> {
        let width = width.max(1);
        let height = height.max(1);
        let stride = width * 4;
        let size = (stride as usize) * (height as usize);
        let mut present_buffer = vec![0u8; size].into_boxed_slice();
        let render_buffer = vec![0u8; size].into_boxed_slice();
        let surface = create_present_surface(&mut present_buffer, width, height, stride)?;
        Ok(Self {
            width,
            height,
            surface,
            present_buffer,
            render_buffer,
        })
    }

    fn render_handle(&self) -> i64 {
        self.render_buffer.as_ptr() as i64
    }

    fn stride(&self) -> i32 {
        self.width * 4
    }

    fn blit_render_to_surface(&mut self) -> Result<(), String> {
        self.surface.flush();
        rgba_to_bgra_copy(&self.render_buffer, &mut self.present_buffer);
        self.surface.mark_dirty();
        Ok(())
    }

    fn copy_render_from(&mut self, source: &FrameTarget) {
        if self.width != source.width || self.height != source.height {
            return;
        }
        self.render_buffer.copy_from_slice(&source.render_buffer);
    }
}

fn create_present_surface(
    present_buffer: &mut [u8],
    width: i32,
    height: i32,
    stride: i32,
) -> Result<ImageSurface, String> {
    unsafe {
        ImageSurface::create_for_data_unsafe(
            present_buffer.as_mut_ptr(),
            cairo::Format::ARgb32,
            width,
            height,
            stride,
        )
    }
    .map_err(|err| format!("surface create failed: {err}"))
}

impl UiMessageSender {
    fn send(&self, msg: UiMessage) -> bool {
        if self.sender.send(msg).is_err() {
            return false;
        }
        self.wake_pipe.notify();
        true
    }
}

impl WakePipe {
    fn new() -> Result<Self, String> {
        let mut fds = [0; 2];
        if unsafe { libc::pipe(fds.as_mut_ptr()) } != 0 {
            return Err(format!(
                "ui wake pipe failed: {}",
                std::io::Error::last_os_error()
            ));
        }

        let wake_pipe = Self {
            read_fd: fds[0],
            write_fd: fds[1],
        };
        configure_pipe_fd(wake_pipe.read_fd)?;
        configure_pipe_fd(wake_pipe.write_fd)?;
        Ok(wake_pipe)
    }

    fn read_fd(&self) -> RawFd {
        self.read_fd
    }

    fn notify(&self) {
        let byte = [1u8];
        loop {
            let rc = unsafe {
                libc::write(
                    self.write_fd,
                    byte.as_ptr() as *const libc::c_void,
                    byte.len(),
                )
            };
            if rc == byte.len() as isize {
                break;
            }
            if rc < 0 {
                match std::io::Error::last_os_error().raw_os_error() {
                    Some(libc::EINTR) => continue,
                    Some(code) if code == libc::EAGAIN || code == libc::EWOULDBLOCK => break,
                    _ => break,
                }
            } else {
                break;
            }
        }
    }

    fn drain(&self) {
        let mut buf = [0u8; 64];
        loop {
            let rc = unsafe {
                libc::read(
                    self.read_fd,
                    buf.as_mut_ptr() as *mut libc::c_void,
                    buf.len(),
                )
            };
            if rc > 0 {
                continue;
            }
            if rc == 0 {
                break;
            }
            match std::io::Error::last_os_error().raw_os_error() {
                Some(libc::EINTR) => continue,
                Some(code) if code == libc::EAGAIN || code == libc::EWOULDBLOCK => break,
                _ => break,
            }
        }
    }
}

impl Drop for WakePipe {
    fn drop(&mut self) {
        unsafe {
            libc::close(self.read_fd);
            libc::close(self.write_fd);
        }
    }
}

fn configure_pipe_fd(fd: RawFd) -> Result<(), String> {
    let fd_flags = unsafe { libc::fcntl(fd, libc::F_GETFD) };
    if fd_flags < 0 {
        return Err(format!(
            "fcntl(F_GETFD) failed for {fd}: {}",
            std::io::Error::last_os_error()
        ));
    }
    if unsafe { libc::fcntl(fd, libc::F_SETFD, fd_flags | libc::FD_CLOEXEC) } < 0 {
        return Err(format!(
            "fcntl(F_SETFD) failed for {fd}: {}",
            std::io::Error::last_os_error()
        ));
    }

    let status_flags = unsafe { libc::fcntl(fd, libc::F_GETFL) };
    if status_flags < 0 {
        return Err(format!(
            "fcntl(F_GETFL) failed for {fd}: {}",
            std::io::Error::last_os_error()
        ));
    }
    if unsafe { libc::fcntl(fd, libc::F_SETFL, status_flags | libc::O_NONBLOCK) } < 0 {
        return Err(format!(
            "fcntl(F_SETFL) failed for {fd}: {}",
            std::io::Error::last_os_error()
        ));
    }

    Ok(())
}

fn create_ui_message_channel() -> Result<(UiMessageSender, UiMessageReceiver), String> {
    let wake_pipe = Arc::new(WakePipe::new()?);
    let (sender, receiver) = mpsc::channel();
    Ok((
        UiMessageSender {
            sender,
            wake_pipe: Arc::clone(&wake_pipe),
        },
        UiMessageReceiver {
            receiver,
            wake_pipe,
        },
    ))
}

struct State {
    client: VolvoxServiceClient,
    sender: UiMessageSender,
    grid_id: i64,
    grid_sessions: HashMap<String, i64>,
    stream_epoch: u64,
    render_stream: Arc<PluginStream>,
    event_stream: Arc<PluginStream>,
    viewport_width: i32,
    viewport_height: i32,
    display_target: Option<FrameTarget>,
    inflight_target: Option<FrameTarget>,
    spare_target: Option<FrameTarget>,
    frame_in_flight: bool,
    frame_awaiting_present: bool,
    needs_followup_frame: bool,
    pending_resize: Option<(i32, i32)>,
    selection: pb::SelectionState,
    selection_mode_idx: u32,
    current_demo: String,
    saved_data: Option<Vec<u8>>,
    clipboard_text: String,
    event_count: u64,
    last_event: String,
    status_note: String,
    frame_pacing_mode: i32,
    target_frame_rate_hz: i32,
    followup_frame_scheduled: bool,
    followup_schedule_seq: u64,
    debug_overlay: bool,
    scroll_blit_enabled: bool,
    hover_enabled: bool,
    col_hidden: bool,
    suppress_entry_changed: bool,
    suppress_combo_changed: bool,
    edit_overlay_cell: Option<(i32, i32)>,
    render_layer_mask: u64,
    /// Tracks whether the engine is in edit mode (for IME commit/preedit).
    engine_editing: bool,
}

fn main() {
    let app = Application::builder().application_id(APP_ID).build();
    app.connect_activate(build_ui);
    app.run();
}

fn build_ui(app: &Application) {
    install_inline_editor_css();

    let root = match build_ui_inner(app) {
        Ok(window) => window,
        Err(err) => build_error_window(app, &err),
    };
    root.present();
}

fn build_ui_inner(app: &Application) -> Result<ApplicationWindow, String> {
    let (tx, rx) = create_ui_message_channel()?;
    let client = VolvoxServiceClient::load_default()?;
    let create = client.create_grid(DEFAULT_WIDTH, DEFAULT_HEIGHT)?;
    let sales_grid_id = create
        .handle
        .map(|handle| handle.id)
        .ok_or_else(|| "plugin returned no grid handle".to_string())?;
    apply_initial_config_for_grid(&client, sales_grid_id, false)?;
    load_sales_json_demo(&client, sales_grid_id)?;

    let render_stream = client.open_render_session()?;
    let event_stream = client.open_event_stream(sales_grid_id)?;
    spawn_render_output_thread(Arc::clone(&render_stream), tx.clone(), 1);
    spawn_grid_event_thread(Arc::clone(&event_stream), tx.clone(), 1);

    let mut grid_sessions = HashMap::new();
    grid_sessions.insert(DEMO_SALES.to_string(), sales_grid_id);

    let mut state = State {
        client,
        sender: tx,
        grid_id: sales_grid_id,
        grid_sessions,
        stream_epoch: 1,
        render_stream,
        event_stream,
        viewport_width: 0,
        viewport_height: 0,
        display_target: None,
        inflight_target: None,
        spare_target: None,
        frame_in_flight: false,
        frame_awaiting_present: false,
        needs_followup_frame: false,
        pending_resize: None,
        selection: pb::SelectionState::default(),
        selection_mode_idx: 0,
        current_demo: DEMO_SALES.to_string(),
        saved_data: None,
        clipboard_text: String::new(),
        event_count: 0,
        last_event: "(none)".to_string(),
        status_note: if create.warnings.is_empty() {
            format!("Plugin loaded from {}", resolve_default_plugin_path())
        } else {
            format!(
                "Plugin loaded with warnings: {}",
                create.warnings.join(", ")
            )
        },
        frame_pacing_mode: pb::FramePacingMode::Auto as i32,
        target_frame_rate_hz: 30,
        followup_frame_scheduled: false,
        followup_schedule_seq: 0,
        debug_overlay: false,
        scroll_blit_enabled: false,
        hover_enabled: true,
        col_hidden: false,
        suppress_entry_changed: false,
        suppress_combo_changed: false,
        edit_overlay_cell: None,
        render_layer_mask: u64::MAX,
        engine_editing: false,
    };

    apply_initial_config(&mut state)?;

    let state = Rc::new(RefCell::new(state));

    let drawing_area = DrawingArea::new();
    drawing_area.set_hexpand(true);
    drawing_area.set_vexpand(true);
    drawing_area.set_focusable(true);

    let grid_overlay = Overlay::new();
    grid_overlay.set_child(Some(&drawing_area));

    let edit_entry = Entry::new();
    edit_entry.add_css_class("volvox-inline-editor");
    edit_entry.set_halign(Align::Start);
    edit_entry.set_valign(Align::Start);
    edit_entry.set_visible(false);
    grid_overlay.add_overlay(&edit_entry);

    #[allow(deprecated)]
    let dropdown_combo = ComboBoxText::new();
    dropdown_combo.add_css_class("volvox-inline-combo");
    dropdown_combo.set_halign(Align::Start);
    dropdown_combo.set_valign(Align::Start);
    dropdown_combo.set_visible(false);
    grid_overlay.add_overlay(&dropdown_combo);

    #[allow(deprecated)]
    let dropdown_combo_editable = ComboBoxText::with_entry();
    dropdown_combo_editable.add_css_class("volvox-inline-combo");
    dropdown_combo_editable.set_halign(Align::Start);
    dropdown_combo_editable.set_valign(Align::Start);
    dropdown_combo_editable.set_visible(false);
    if let Some(entry) = combo_entry_widget(&dropdown_combo_editable) {
        entry.add_css_class("volvox-inline-editor");
    }
    grid_overlay.add_overlay(&dropdown_combo_editable);

    let status_label = Label::new(None);
    {
        let st = state.borrow();
        update_status_label(&st, &status_label);
    }

    let toolbar_row1 = GtkBox::new(Orientation::Horizontal, 4);
    let toolbar_row2 = GtkBox::new(Orientation::Horizontal, 4);

    let btn_demo_sales = Button::with_label("Sales");
    let btn_demo_hierarchy = Button::with_label("Hierarchy");
    let btn_demo_stress = Button::with_label("Stress");
    let selection_mode = DropDown::from_strings(&SELECTION_MODE_LABELS);
    selection_mode.set_selected(0);
    let chk_debug = CheckButton::with_label("Debug");
    let chk_scroll_blit = CheckButton::with_label("ScrollBlit");
    let frame_pacing_box = GtkBox::new(Orientation::Horizontal, 4);
    let frame_pacing_label = Label::new(Some("Pacing"));
    let frame_pacing_mode = DropDown::from_strings(&FRAME_PACING_LABELS);
    let frame_pacing_fixed_label = Label::new(Some("Hz"));
    let frame_pacing_fixed_hz = SpinButton::with_range(1.0, 1000.0, 1.0);
    frame_pacing_mode.set_selected(frame_pacing_dropdown_index(
        state.borrow().frame_pacing_mode,
    ));
    frame_pacing_fixed_hz.set_digits(0);
    frame_pacing_fixed_hz.set_numeric(true);
    frame_pacing_fixed_hz.set_width_chars(4);
    frame_pacing_fixed_hz.set_value(state.borrow().target_frame_rate_hz as f64);
    frame_pacing_fixed_hz.set_tooltip_text(Some("Target Hz used when frame pacing is Fixed"));
    sync_frame_pacing_widgets(
        state.borrow().frame_pacing_mode,
        &frame_pacing_fixed_label,
        &frame_pacing_fixed_hz,
    );
    frame_pacing_box.append(&frame_pacing_label);
    frame_pacing_box.append(&frame_pacing_mode);
    frame_pacing_box.append(&frame_pacing_fixed_label);
    frame_pacing_box.append(&frame_pacing_fixed_hz);
    let btn_sort_asc = Button::with_label("SortAsc");
    let btn_sort_desc = Button::with_label("SortDesc");
    let chk_hover = CheckButton::with_label("Hover");
    chk_hover.set_active(true);
    chk_scroll_blit.set_active(state.borrow().scroll_blit_enabled);

    let btn_save = Button::with_label("SaveCSV");
    let btn_load = Button::with_label("LoadCSV");
    let btn_copy = Button::with_label("Copy");
    let btn_paste = Button::with_label("Paste");
    let btn_add_row = Button::with_label("AddRow");
    let btn_del_row = Button::with_label("DelRow");
    let btn_hide_col = Button::with_label("HideCol");

    toolbar_row1.append(&btn_demo_sales);
    toolbar_row1.append(&btn_demo_hierarchy);
    toolbar_row1.append(&btn_demo_stress);
    toolbar_row1.append(&Separator::new(Orientation::Vertical));
    toolbar_row1.append(&selection_mode);
    toolbar_row1.append(&chk_debug);
    toolbar_row1.append(&chk_scroll_blit);
    toolbar_row1.append(&frame_pacing_box);
    toolbar_row1.append(&btn_sort_asc);
    toolbar_row1.append(&btn_sort_desc);
    toolbar_row1.append(&chk_hover);

    toolbar_row2.append(&btn_save);
    toolbar_row2.append(&btn_load);
    toolbar_row2.append(&btn_copy);
    toolbar_row2.append(&btn_paste);
    toolbar_row2.append(&btn_add_row);
    toolbar_row2.append(&btn_del_row);
    toolbar_row2.append(&btn_hide_col);

    // Layer checkboxes inside a scrollable popover
    let layer_box = GtkBox::new(Orientation::Vertical, 2);
    let btn_all = Button::with_label("All On");
    let btn_none = Button::with_label("All Off");
    let btn_row = GtkBox::new(Orientation::Horizontal, 4);
    btn_row.append(&btn_all);
    btn_row.append(&btn_none);
    layer_box.append(&btn_row);
    layer_box.append(&Separator::new(Orientation::Horizontal));

    let layer_checks: Vec<CheckButton> = (0..LAYER_COUNT)
        .map(|i| {
            let chk = CheckButton::with_label(LAYER_LABELS[i]);
            chk.set_active(true);
            layer_box.append(&chk);
            chk
        })
        .collect();

    let scrolled = ScrolledWindow::new();
    scrolled.set_child(Some(&layer_box));
    scrolled.set_min_content_height(400);
    scrolled.set_min_content_width(200);

    let popover = Popover::new();
    popover.set_child(Some(&scrolled));

    let menu_btn = MenuButton::new();
    menu_btn.set_label("Layers");
    menu_btn.set_popover(Some(&popover));

    toolbar_row1.append(&menu_btn);

    set_demo_button_active(&btn_demo_sales, true);
    set_demo_button_active(&btn_demo_hierarchy, false);
    set_demo_button_active(&btn_demo_stress, false);

    drawing_area.set_draw_func({
        let state = Rc::clone(&state);
        move |area, cr, _w, _h| {
            {
                let st = state.borrow();
                if let Some(target) = &st.display_target {
                    let surface = &target.surface;
                    let _ = cr.set_source_surface(surface, 0.0, 0.0);
                    let _ = cr.paint();
                } else {
                    cr.set_source_rgb(0.92, 0.92, 0.92);
                    let _ = cr.paint();
                }
            }

            let should_schedule = {
                let Ok(mut st) = state.try_borrow_mut() else {
                    return;
                };
                if !st.frame_awaiting_present {
                    false
                } else {
                    st.frame_awaiting_present = false;
                    st.needs_followup_frame && !st.followup_frame_scheduled
                }
            };

            if should_schedule {
                schedule_followup_frame(&state, area);
            }
        }
    });

    attach_ui_message_pump(
        Rc::clone(&state),
        drawing_area.clone(),
        edit_entry.clone(),
        dropdown_combo.clone(),
        dropdown_combo_editable.clone(),
        status_label.clone(),
        rx,
    );

    {
        let state = Rc::clone(&state);
        drawing_area.connect_resize(move |_area, w, h| {
            if let Ok(mut st) = state.try_borrow_mut() {
                let width = w.max(1);
                let height = h.max(1);
                let pending_matches = st.pending_resize == Some((width, height));
                let inflight_matches = st
                    .inflight_target
                    .as_ref()
                    .is_some_and(|target| target.width == width && target.height == height);
                let display_matches = st
                    .display_target
                    .as_ref()
                    .is_some_and(|target| target.width == width && target.height == height);
                let viewport_matches = st.viewport_width == width && st.viewport_height == height;

                // GTK can deliver repeated size-allocation callbacks without an
                // actual size change; don't turn those into clean render requests.
                if pending_matches || ((inflight_matches || display_matches) && viewport_matches) {
                    return;
                }

                st.pending_resize = Some((width, height));
                let _ = request_frame(&mut st);
            }
        });
    }

    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let edit_entry_ref = edit_entry.clone();
        let combo = dropdown_combo.clone();
        let combo_editable = dropdown_combo_editable.clone();
        edit_entry.connect_activate(move |entry| {
            run_action(&state, &area, &status, |st| {
                let text = truncated_text(&entry.text(), current_edit_max_length(st));
                st.client.edit_commit(st.grid_id, text)?;
                hide_host_editors(&edit_entry_ref, &combo, &combo_editable);
                area.grab_focus();
                Ok("Edit committed".to_string())
            });
        });
    }

    {
        let state = Rc::clone(&state);
        let status = status_label.clone();
        let entry = edit_entry.clone();
        edit_entry.connect_changed(move |widget| {
            let Ok(mut st) = state.try_borrow_mut() else {
                return;
            };
            if st.suppress_entry_changed {
                return;
            }
            let text = truncated_text(&widget.text(), current_edit_max_length(&st));
            if let Err(err) = st.client.edit_set_text(st.grid_id, text) {
                st.status_note = format!("Edit update failed: {err}");
            }
            update_status_label(&st, &status);
            let _ = request_frame(&mut st);
            drop(st);
            entry.set_position(entry.text_length() as i32);
        });
    }

    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let entry = edit_entry.clone();
        let combo = dropdown_combo.clone();
        let combo_editable = dropdown_combo_editable.clone();
        let key = EventControllerKey::new();
        key.connect_key_pressed(move |_ctrl, keyval, _keycode, modifier| {
            let key_code = gdk_keyval_to_vk(keyval);
            if key_code != 27 && key_code != 9 {
                return glib::Propagation::Proceed;
            }
            run_action(&state, &area, &status, |st| {
                if key_code == 27 {
                    st.client.edit_cancel(st.grid_id)?;
                    hide_host_editors(&entry, &combo, &combo_editable);
                    area.grab_focus();
                    Ok("Edit canceled".to_string())
                } else {
                    let text = truncated_text(&entry.text(), current_edit_max_length(st));
                    st.client.edit_commit(st.grid_id, text)?;
                    hide_host_editors(&entry, &combo, &combo_editable);
                    area.grab_focus();
                    let mods = gdk_modifier_to_flags(modifier);
                    send_key_input(st, pb::key_event::Type::KeyDown, 9, mods, String::new())?;
                    Ok("Edit committed".to_string())
                }
            });
            glib::Propagation::Stop
        });
        edit_entry.add_controller(key);
    }

    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let entry = edit_entry.clone();
        let combo_editable = dropdown_combo_editable.clone();
        dropdown_combo.connect_changed(move |combo| {
            commit_combo_selection(
                &state,
                &area,
                &status,
                &entry,
                combo,
                &combo_editable,
                false,
            );
        });
    }

    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let entry = edit_entry.clone();
        let combo_readonly = dropdown_combo.clone();
        dropdown_combo_editable.connect_changed(move |combo| {
            commit_combo_selection(&state, &area, &status, &entry, &combo_readonly, combo, true);
        });
    }

    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let entry = edit_entry.clone();
        let combo = dropdown_combo.clone();
        let combo_editable = dropdown_combo_editable.clone();
        let key = EventControllerKey::new();
        key.connect_key_pressed(move |_ctrl, keyval, _keycode, modifier| {
            handle_combo_key(
                &state,
                &area,
                &status,
                &entry,
                &combo,
                &combo_editable,
                keyval,
                modifier,
                false,
            )
        });
        dropdown_combo.add_controller(key);
    }

    if let Some(combo_entry) = combo_entry_widget(&dropdown_combo_editable) {
        let combo_changed_state = Rc::clone(&state);
        let combo_changed_status = status_label.clone();
        let combo_editable = dropdown_combo_editable.clone();
        combo_entry.connect_changed(move |widget| {
            let Ok(mut st) = combo_changed_state.try_borrow_mut() else {
                return;
            };
            if st.suppress_combo_changed || !combo_editable.is_visible() {
                return;
            }
            let text = truncated_text(&widget.text(), current_edit_max_length(&st));
            if let Err(err) = st.client.edit_set_text(st.grid_id, text) {
                st.status_note = format!("Combo edit update failed: {err}");
            }
            update_status_label(&st, &combo_changed_status);
            let _ = request_frame(&mut st);
            drop(st);
            widget.set_position(widget.text_length() as i32);
        });

        let combo_activate_state = Rc::clone(&state);
        let combo_activate_area = drawing_area.clone();
        let combo_activate_status = status_label.clone();
        let combo_activate_entry = edit_entry.clone();
        let combo_activate_readonly = dropdown_combo.clone();
        let combo_activate_editable = dropdown_combo_editable.clone();
        combo_entry.connect_activate(move |widget| {
            run_action(
                &combo_activate_state,
                &combo_activate_area,
                &combo_activate_status,
                |st| {
                    let text = truncated_text(&widget.text(), current_edit_max_length(st));
                    st.client.edit_commit(st.grid_id, text)?;
                    hide_host_editors(
                        &combo_activate_entry,
                        &combo_activate_readonly,
                        &combo_activate_editable,
                    );
                    combo_activate_area.grab_focus();
                    Ok("Combo committed".to_string())
                },
            );
        });

        let combo_key_state = Rc::clone(&state);
        let combo_key_area = drawing_area.clone();
        let combo_key_status = status_label.clone();
        let combo_key_entry = edit_entry.clone();
        let combo_key_readonly = dropdown_combo.clone();
        let combo_key_editable = dropdown_combo_editable.clone();
        let key = EventControllerKey::new();
        key.connect_key_pressed(move |_ctrl, keyval, _keycode, modifier| {
            handle_combo_key(
                &combo_key_state,
                &combo_key_area,
                &combo_key_status,
                &combo_key_entry,
                &combo_key_readonly,
                &combo_key_editable,
                keyval,
                modifier,
                true,
            )
        });
        combo_entry.add_controller(key);
    }

    let click = GestureClick::new();
    click.set_button(0);
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let entry = edit_entry.clone();
        let combo = dropdown_combo.clone();
        let combo_editable = dropdown_combo_editable.clone();
        click.connect_pressed(move |gesture, n_press, x, y| {
            area.grab_focus();
            if gtk4::prelude::WidgetExt::is_visible(&entry) && !widget_contains_point(&entry, x, y)
            {
                hide_host_editors(&entry, &combo, &combo_editable);
            }
            run_action(&state, &area, &status, |st| {
                let button = gesture.current_button() as i32;
                let modifier = gdk_modifier_to_flags(gesture.current_event_state());
                send_pointer_input(
                    st,
                    pb::pointer_event::Type::Down,
                    x as f32,
                    y as f32,
                    modifier,
                    button,
                    n_press >= 2,
                )?;
                Ok(format!("Pointer down @ {:.0},{:.0}", x, y))
            });
        });
    }
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        click.connect_released(move |gesture, _n_press, x, y| {
            run_action(&state, &area, &status, |st| {
                let button = gesture.current_button() as i32;
                let modifier = gdk_modifier_to_flags(gesture.current_event_state());
                send_pointer_input(
                    st,
                    pb::pointer_event::Type::Up,
                    x as f32,
                    y as f32,
                    modifier,
                    button,
                    false,
                )?;
                Ok(format!("Pointer up @ {:.0},{:.0}", x, y))
            });
        });
    }
    drawing_area.add_controller(click);

    let motion = EventControllerMotion::new();
    {
        let state = Rc::clone(&state);
        let status = status_label.clone();
        motion.connect_motion(move |ctrl, x, y| {
            let Ok(mut st) = state.try_borrow_mut() else {
                return;
            };
            let event_state = ctrl.current_event_state();
            if let Err(err) = send_pointer_input(
                &mut st,
                pb::pointer_event::Type::Move,
                x as f32,
                y as f32,
                gdk_modifier_to_flags(event_state),
                gdk_button_mask_to_buttons(event_state),
                false,
            ) {
                st.status_note = format!("Pointer move failed: {err}");
            }
            update_status_label(&st, &status);
            let _ = request_frame(&mut st);
            drop(st);
        });
    }
    drawing_area.add_controller(motion);

    let scroll = EventControllerScroll::new(gtk4::EventControllerScrollFlags::BOTH_AXES);
    {
        let state = Rc::clone(&state);
        let status = status_label.clone();
        scroll.connect_scroll(move |_ctrl, dx, dy| {
            let Ok(mut st) = state.try_borrow_mut() else {
                return glib::Propagation::Stop;
            };
            if let Err(err) = send_scroll_input(
                &mut st,
                dx as f32 * WHEEL_SCROLL_GAIN,
                dy as f32 * WHEEL_SCROLL_GAIN,
            ) {
                st.status_note = format!("Scroll failed: {err}");
            }
            update_status_label(&st, &status);
            let _ = request_frame(&mut st);
            drop(st);
            glib::Propagation::Stop
        });
    }
    drawing_area.add_controller(scroll);

    let im_context = gtk4::IMMulticontext::new();
    im_context.set_client_widget(Some(&drawing_area));
    let key = EventControllerKey::new();
    key.set_im_context(Some(&im_context));

    // IME commit: final text from IME (e.g. "a" for English, "한" for Korean).
    {
        let state = Rc::clone(&state);
        let status = status_label.clone();
        let area = drawing_area.clone();
        im_context.connect_commit(move |_ctx, text| {
            let Ok(mut st) = state.try_borrow_mut() else {
                return;
            };

            if !st.engine_editing {
                // Idle cell: send KeyPress for first char to trigger auto-edit,
                // then commit_preedit for remaining chars (engine is now editing).
                let mut chars = text.chars();
                if let Some(first) = chars.next() {
                    let _ = send_key_input(
                        &mut st,
                        pb::key_event::Type::KeyPress,
                        0,
                        0,
                        first.to_string(),
                    );
                    // The engine processes KeyPress synchronously on the render
                    // thread, entering edit mode. Mark it here so subsequent
                    // commits in the same pump don't re-trigger auto-edit.
                    st.engine_editing = true;
                }
                // Remaining chars: engine is already editing, insert directly.
                let rest: String = chars.collect();
                if !rest.is_empty() {
                    let _ = st.client.edit_commit_preedit(st.grid_id, &rest);
                }
            } else {
                // Editing: commit preedit text into edit_text.
                if let Err(err) = st.client.edit_commit_preedit(st.grid_id, text) {
                    st.status_note = format!("IME commit failed: {err}");
                }
            }
            update_status_label(&st, &status);
            let _ = request_frame(&mut st);
            area.queue_draw();
        });
    }

    // IME preedit changed: live composition updates (e.g. "ㅇ" → "아").
    {
        let state = Rc::clone(&state);
        let status = status_label.clone();
        let area = drawing_area.clone();
        im_context.connect_preedit_changed(move |ctx| {
            let (text, _attrs, cursor) = ctx.preedit_string();
            let Ok(mut st) = state.try_borrow_mut() else {
                return;
            };

            if !text.is_empty() && !st.engine_editing {
                // Composition starting on idle cell: begin edit with empty text.
                let sel = st.selection.clone();
                if let Ok(()) =
                    st.client
                        .edit_start_empty(st.grid_id, sel.active_row, sel.active_col)
                {
                    st.engine_editing = true;
                }
            }

            // Forward preedit to engine.
            if let Err(err) = st
                .client
                .edit_set_preedit(st.grid_id, text.to_string(), cursor)
            {
                st.status_note = format!("Preedit update failed: {err}");
            }
            update_status_label(&st, &status);
            let _ = request_frame(&mut st);
            area.queue_draw();
        });
    }

    // Key pressed: only fires for keys the IMContext doesn't handle
    // (arrows, escape, enter, tab, function keys, etc.)
    {
        let state = Rc::clone(&state);
        let status = status_label.clone();
        key.connect_key_pressed(move |_ctrl, keyval, _keycode, modifier| {
            let key_code = gdk_keyval_to_vk(keyval);
            if key_code == 0 {
                return glib::Propagation::Proceed;
            }

            let Ok(mut st) = state.try_borrow_mut() else {
                return glib::Propagation::Stop;
            };
            let flags = gdk_modifier_to_flags(modifier);
            if let Err(err) = send_key_input(
                &mut st,
                pb::key_event::Type::KeyDown,
                key_code,
                flags,
                String::new(),
            ) {
                st.status_note = format!("Key down failed: {err}");
            }
            update_status_label(&st, &status);
            let _ = request_frame(&mut st);
            drop(st);
            glib::Propagation::Stop
        });
    }
    {
        let state = Rc::clone(&state);
        let status = status_label.clone();
        key.connect_key_released(move |_ctrl, keyval, _keycode, modifier| {
            let key_code = gdk_keyval_to_vk(keyval);
            if key_code == 0 {
                return;
            }

            let Ok(mut st) = state.try_borrow_mut() else {
                return;
            };
            let flags = gdk_modifier_to_flags(modifier);
            if let Err(err) = send_key_input(
                &mut st,
                pb::key_event::Type::KeyUp,
                key_code,
                flags,
                String::new(),
            ) {
                st.status_note = format!("Key up failed: {err}");
            }
            update_status_label(&st, &status);
            let _ = request_frame(&mut st);
            drop(st);
        });
    }
    drawing_area.add_controller(key);

    // IMContext focus management.
    {
        let im = im_context.clone();
        let focus_ctrl = gtk4::EventControllerFocus::new();
        focus_ctrl.connect_enter(move |_| {
            im.focus_in();
        });
        let im2 = im_context;
        focus_ctrl.connect_leave(move |_| {
            im2.focus_out();
        });
        drawing_area.add_controller(focus_ctrl);
    }

    connect_demo_button(
        &btn_demo_sales,
        Rc::clone(&state),
        drawing_area.clone(),
        status_label.clone(),
        edit_entry.clone(),
        dropdown_combo.clone(),
        dropdown_combo_editable.clone(),
        btn_demo_sales.clone(),
        btn_demo_hierarchy.clone(),
        btn_demo_stress.clone(),
        DEMO_SALES,
    );
    connect_demo_button(
        &btn_demo_hierarchy,
        Rc::clone(&state),
        drawing_area.clone(),
        status_label.clone(),
        edit_entry.clone(),
        dropdown_combo.clone(),
        dropdown_combo_editable.clone(),
        btn_demo_sales.clone(),
        btn_demo_hierarchy.clone(),
        btn_demo_stress.clone(),
        DEMO_HIERARCHY,
    );
    connect_demo_button(
        &btn_demo_stress,
        Rc::clone(&state),
        drawing_area.clone(),
        status_label.clone(),
        edit_entry.clone(),
        dropdown_combo.clone(),
        dropdown_combo_editable.clone(),
        btn_demo_sales.clone(),
        btn_demo_hierarchy.clone(),
        btn_demo_stress.clone(),
        DEMO_STRESS,
    );

    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let fixed_label = frame_pacing_fixed_label.clone();
        let fixed_hz = frame_pacing_fixed_hz.clone();
        frame_pacing_mode.connect_selected_notify(move |dd| {
            let mode = frame_pacing_mode_value(dd.selected());
            sync_frame_pacing_widgets(mode, &fixed_label, &fixed_hz);
            run_action(&state, &area, &status, |st| {
                st.frame_pacing_mode = mode;
                st.target_frame_rate_hz = fixed_hz.value_as_int();
                apply_host_runtime_config(st, st.grid_id)?;
                Ok(format!(
                    "Frame pacing {}",
                    frame_pacing_status_text(st.frame_pacing_mode, st.target_frame_rate_hz)
                ))
            });
        });
    }

    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        frame_pacing_fixed_hz.connect_value_changed(move |spin| {
            run_action(&state, &area, &status, |st| {
                st.target_frame_rate_hz = spin.value_as_int();
                apply_host_runtime_config(st, st.grid_id)?;
                Ok(format!(
                    "Frame pacing {}",
                    frame_pacing_status_text(st.frame_pacing_mode, st.target_frame_rate_hz)
                ))
            });
        });
    }

    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        chk_debug.connect_toggled(move |chk| {
            run_action(&state, &area, &status, |st| {
                st.debug_overlay = chk.is_active();
                apply_host_runtime_config(st, st.grid_id)?;
                Ok(if st.debug_overlay {
                    "Debug overlay enabled".to_string()
                } else {
                    "Debug overlay disabled".to_string()
                })
            });
        });
    }

    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        chk_scroll_blit.connect_toggled(move |chk| {
            run_action(&state, &area, &status, |st| {
                st.scroll_blit_enabled = chk.is_active();
                apply_host_runtime_config(st, st.grid_id)?;
                Ok(if st.scroll_blit_enabled {
                    "Scroll blit enabled".to_string()
                } else {
                    "Scroll blit disabled".to_string()
                })
            });
        });
    }

    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        selection_mode.connect_selected_notify(move |dd| {
            run_action(&state, &area, &status, |st| {
                let idx = dd.selected();
                st.selection_mode_idx = idx;
                apply_host_runtime_config(st, st.grid_id)?;
                Ok(format!(
                    "Selection mode: {}",
                    SELECTION_MODE_LABELS[idx as usize]
                ))
            });
        });
    }

    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_sort_asc.connect_clicked(move |_| {
            run_action(&state, &area, &status, |st| {
                let col = active_col(st);
                st.client.sort(
                    st.grid_id,
                    col,
                    pb::SortOrder::SortAscending,
                    pb::SortType::Auto,
                )?;
                Ok(format!("Sorted column {}", col + 1))
            });
        });
    }
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_sort_desc.connect_clicked(move |_| {
            run_action(&state, &area, &status, |st| {
                let col = active_col(st);
                st.client.sort(
                    st.grid_id,
                    col,
                    pb::SortOrder::SortDescending,
                    pb::SortType::Auto,
                )?;
                Ok(format!("Sorted column {} desc", col + 1))
            });
        });
    }
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        chk_hover.connect_toggled(move |chk| {
            run_action(&state, &area, &status, |st| {
                st.hover_enabled = chk.is_active();
                apply_host_runtime_config(st, st.grid_id)?;
                Ok(if st.hover_enabled {
                    "Hover enabled".to_string()
                } else {
                    "Hover disabled".to_string()
                })
            });
        });
    }

    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_save.connect_clicked(move |_| {
            run_action(&state, &area, &status, |st| {
                let resp = st.client.export(
                    st.grid_id,
                    pb::ExportFormat::ExportCsv,
                    pb::ExportScope::ExportAll,
                )?;
                let bytes = resp.data.len();
                st.saved_data = Some(resp.data);
                Ok(format!("Saved {} CSV bytes", bytes))
            });
        });
    }
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_load.connect_clicked(move |_| {
            run_action(&state, &area, &status, |st| {
                let data = st
                    .saved_data
                    .clone()
                    .ok_or_else(|| "nothing saved yet".to_string())?;
                let result = st.client.load_data(st.grid_id, data)?;
                Ok(format!("Loaded {} rows from CSV", result.rows))
            });
        });
    }
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_copy.connect_clicked(move |_| {
            run_action(&state, &area, &status, |st| {
                let resp = st.client.clipboard_copy(st.grid_id)?;
                st.clipboard_text = resp.text.clone();
                set_system_clipboard_text(&resp.text);
                Ok(format!("Copied {} chars", resp.text.chars().count()))
            });
        });
    }
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_paste.connect_clicked(move |_| {
            run_action(&state, &area, &status, |st| {
                if st.clipboard_text.is_empty() {
                    return Ok("Clipboard cache is empty".to_string());
                }
                let text = st.clipboard_text.clone();
                st.client.clipboard_paste(st.grid_id, text)?;
                Ok("Pasted cached clipboard text".to_string())
            });
        });
    }
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_add_row.connect_clicked(move |_| {
            run_action(&state, &area, &status, |st| {
                let idx = active_row(st).max(0) + 1;
                st.client.insert_rows(st.grid_id, idx, 1)?;
                Ok(format!("Inserted row at {}", idx + 1))
            });
        });
    }
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_del_row.connect_clicked(move |_| {
            run_action(&state, &area, &status, |st| {
                let idx = active_row(st).max(0);
                st.client.remove_rows(st.grid_id, idx, 1)?;
                Ok(format!("Removed row {}", idx + 1))
            });
        });
    }
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let button = btn_hide_col.clone();
        btn_hide_col.connect_clicked(move |_| {
            run_action(&state, &area, &status, |st| {
                st.col_hidden = !st.col_hidden;
                let col = active_col(st);
                st.client
                    .define_column_hidden(st.grid_id, col, st.col_hidden)?;
                button.set_label(if st.col_hidden {
                    "HideCol: ON"
                } else {
                    "HideCol"
                });
                Ok(format!(
                    "{} column {}",
                    if st.col_hidden { "Hidden" } else { "Shown" },
                    col + 1
                ))
            });
        });
    }
    // ── Layer checkbox handlers ──
    for i in 0..LAYER_COUNT {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        layer_checks[i].connect_toggled(move |chk| {
            run_action(&state, &area, &status, |st| {
                if chk.is_active() {
                    st.render_layer_mask |= 1u64 << i;
                } else {
                    st.render_layer_mask &= !(1u64 << i);
                }
                apply_host_runtime_config(st, st.grid_id)?;
                let on = st.render_layer_mask.count_ones();
                Ok(format!(
                    "{}: {} ({}/{})",
                    LAYER_LABELS[i],
                    if chk.is_active() { "ON" } else { "OFF" },
                    on,
                    LAYER_COUNT
                ))
            });
        });
    }
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let checks: Vec<CheckButton> = layer_checks.iter().cloned().collect();
        btn_all.connect_clicked(move |_| {
            for chk in &checks {
                chk.set_active(true);
            }
            run_action(&state, &area, &status, |st| {
                st.render_layer_mask = u64::MAX;
                apply_host_runtime_config(st, st.grid_id)?;
                Ok("All layers enabled".to_string())
            });
        });
    }
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let checks: Vec<CheckButton> = layer_checks.iter().cloned().collect();
        btn_none.connect_clicked(move |_| {
            for chk in &checks {
                chk.set_active(false);
            }
            run_action(&state, &area, &status, |st| {
                st.render_layer_mask = 0;
                apply_host_runtime_config(st, st.grid_id)?;
                Ok("All layers disabled".to_string())
            });
        });
    }
    let vbox = GtkBox::new(Orientation::Vertical, 0);
    vbox.append(&toolbar_row1);
    vbox.append(&toolbar_row2);
    vbox.append(&Separator::new(Orientation::Horizontal));
    vbox.append(&grid_overlay);
    vbox.append(&Separator::new(Orientation::Horizontal));
    vbox.append(&status_label);

    let window = ApplicationWindow::builder()
        .application(app)
        .title("VolvoxGrid GTK4 - Plugin FFI Test")
        .default_width(DEFAULT_WIDTH)
        .default_height(DEFAULT_HEIGHT)
        .child(&vbox)
        .build();

    {
        let area = drawing_area.clone();
        window.connect_show(move |_win| {
            area.grab_focus();
        });
    }

    Ok(window)
}

fn build_error_window(app: &Application, err: &str) -> ApplicationWindow {
    let label = Label::new(Some(err));
    ApplicationWindow::builder()
        .application(app)
        .title("VolvoxGrid GTK4 - Startup Error")
        .default_width(900)
        .default_height(240)
        .child(&label)
        .build()
}

fn install_inline_editor_css() {
    let provider = CssProvider::new();
    provider.load_from_data(INLINE_EDITOR_CSS);
    if let Some(display) = gdk::Display::default() {
        gtk4::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }
}

impl VolvoxServiceClient {
    fn load_default() -> Result<Self, String> {
        let path = resolve_default_plugin_path();
        let plugin = PluginLibrary::load(&path)?;
        Ok(Self { plugin })
    }

    fn create_grid(&self, width: i32, height: i32) -> Result<pb::CreateResponse, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Create",
            &pb::CreateRequest {
                viewport_width: width,
                viewport_height: height,
                scale: 1.0,
                config: Some(pb::GridConfig {
                    layout: Some(pb::LayoutConfig {
                        rows: Some(200),
                        cols: Some(12),
                        fixed_rows: Some(1),
                        fixed_cols: Some(0),
                        default_row_height: Some(24),
                        default_col_width: Some(110),
                        ..Default::default()
                    }),
                    selection: Some(pb::SelectionConfig {
                        mode: Some(pb::SelectionMode::SelectionFree as i32),
                        visibility: Some(pb::SelectionVisibility::SelectionVisAlways as i32),
                        ..Default::default()
                    }),
                    scrolling: Some(pb::ScrollConfig {
                        scroll_bar: Some(pb::ScrollBarConfig {
                            show_h: Some(pb::ScrollBarMode::ScrollbarModeAuto as i32),
                            show_v: Some(pb::ScrollBarMode::ScrollbarModeAuto as i32),
                            ..Default::default()
                        }),
                        fling_enabled: Some(true),
                        fast_scroll: Some(true),
                        ..Default::default()
                    }),
                    rendering: Some(pb::RenderConfig {
                        renderer_mode: Some(pb::RendererMode::RendererCpu as i32),
                        animation_enabled: Some(true),
                        frame_pacing_mode: Some(pb::FramePacingMode::Auto as i32),
                        target_frame_rate_hz: Some(30),
                        ..Default::default()
                    }),
                    ..Default::default()
                }),
            },
        )
    }

    fn configure(&self, grid_id: i64, config: pb::GridConfig) -> Result<(), String> {
        let _: pb::ConfigureResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Configure",
            &pb::ConfigureRequest {
                grid_id,
                config: Some(config),
            },
        )?;
        Ok(())
    }

    fn load_demo(&self, grid_id: i64, demo: &str) -> Result<(), String> {
        let _: pb::LoadDemoResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/LoadDemo",
            &pb::LoadDemoRequest {
                grid_id,
                demo: demo.to_string(),
            },
        )?;
        Ok(())
    }

    fn get_demo_data(&self, demo: &str) -> Result<Vec<u8>, String> {
        let response: pb::GetDemoDataResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/GetDemoData",
            &pb::GetDemoDataRequest {
                demo: demo.to_string(),
            },
        )?;
        Ok(response.data)
    }

    fn get_node(&self, grid_id: i64, row: i32) -> Result<pb::NodeInfo, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/GetNode",
            &pb::GetNodeRequest {
                grid_id,
                row,
                relation: None,
            },
        )
    }

    fn merge_cells(
        &self,
        grid_id: i64,
        row1: i32,
        col1: i32,
        row2: i32,
        col2: i32,
    ) -> Result<(), String> {
        let _: pb::MergeCellsResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/MergeCells",
            &pb::MergeCellsRequest {
                grid_id,
                range: Some(pb::CellRange {
                    row1,
                    col1,
                    row2,
                    col2,
                }),
            },
        )?;
        Ok(())
    }

    fn refresh(&self, grid_id: i64) -> Result<(), String> {
        let _: pb::RefreshResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Refresh",
            &pb::GridHandle { id: grid_id },
        )?;
        Ok(())
    }

    fn open_render_session(&self) -> Result<Arc<PluginStream>, String> {
        self.plugin
            .open_stream("/volvoxgrid.v1.VolvoxGridService/RenderSession")
    }

    fn open_event_stream(&self, grid_id: i64) -> Result<Arc<PluginStream>, String> {
        let stream = self
            .plugin
            .open_stream("/volvoxgrid.v1.VolvoxGridService/EventStream")?;
        let request = pb::GridHandle { id: grid_id };
        stream.send_raw(&request.encode_to_vec())?;
        stream.close_send();
        Ok(stream)
    }

    fn sort(
        &self,
        grid_id: i64,
        col: i32,
        order: pb::SortOrder,
        sort_type: pb::SortType,
    ) -> Result<(), String> {
        let _: pb::SortResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Sort",
            &pb::SortRequest {
                grid_id,
                sort_columns: vec![pb::SortColumn {
                    col,
                    order: Some(order as i32),
                    r#type: Some(sort_type as i32),
                }],
            },
        )?;
        Ok(())
    }

    fn outline(&self, grid_id: i64, level: i32) -> Result<(), String> {
        let _: pb::OutlineResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Outline",
            &pb::OutlineRequest { grid_id, level },
        )?;
        Ok(())
    }

    fn edit_start(&self, grid_id: i64, row: i32, col: i32) -> Result<(), String> {
        let _: pb::EditState = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Edit",
            &pb::EditCommand {
                grid_id,
                command: Some(pb::edit_command::Command::Start(pb::EditStart {
                    row,
                    col,
                    select_all: Some(true),
                    caret_end: Some(true),
                    seed_text: None,
                    formula_mode: None,
                })),
            },
        )?;
        Ok(())
    }

    fn edit_commit(&self, grid_id: i64, text: String) -> Result<(), String> {
        let _: pb::EditState = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Edit",
            &pb::EditCommand {
                grid_id,
                command: Some(pb::edit_command::Command::Commit(pb::EditCommit {
                    text: Some(text),
                })),
            },
        )?;
        Ok(())
    }

    fn edit_cancel(&self, grid_id: i64) -> Result<(), String> {
        let _: pb::EditState = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Edit",
            &pb::EditCommand {
                grid_id,
                command: Some(pb::edit_command::Command::Cancel(pb::EditCancel {})),
            },
        )?;
        Ok(())
    }

    fn edit_set_text(&self, grid_id: i64, text: String) -> Result<(), String> {
        let _: pb::EditState = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Edit",
            &pb::EditCommand {
                grid_id,
                command: Some(pb::edit_command::Command::SetText(pb::EditSetText { text })),
            },
        )?;
        Ok(())
    }

    fn edit_set_preedit(&self, grid_id: i64, text: String, cursor: i32) -> Result<(), String> {
        let _: pb::EditState = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Edit",
            &pb::EditCommand {
                grid_id,
                command: Some(pb::edit_command::Command::SetPreedit(pb::EditSetPreedit {
                    text,
                    cursor,
                    commit: false,
                })),
            },
        )?;
        Ok(())
    }

    fn edit_start_empty(&self, grid_id: i64, row: i32, col: i32) -> Result<(), String> {
        let _: pb::EditState = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Edit",
            &pb::EditCommand {
                grid_id,
                command: Some(pb::edit_command::Command::Start(pb::EditStart {
                    row,
                    col,
                    select_all: None,
                    caret_end: None,
                    seed_text: Some(String::new()),
                    formula_mode: None,
                })),
            },
        )?;
        Ok(())
    }

    fn edit_commit_preedit(&self, grid_id: i64, committed_text: &str) -> Result<(), String> {
        let _: pb::EditState = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Edit",
            &pb::EditCommand {
                grid_id,
                command: Some(pb::edit_command::Command::SetPreedit(pb::EditSetPreedit {
                    text: committed_text.to_string(),
                    cursor: 0,
                    commit: true,
                })),
            },
        )?;
        Ok(())
    }

    fn find_text(&self, grid_id: i64, col: i32, start_row: i32, text: &str) -> Result<i32, String> {
        let resp: pb::FindResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Find",
            &pb::FindRequest {
                grid_id,
                col,
                start_row,
                query: Some(pb::find_request::Query::TextQuery(pb::TextQuery {
                    text: text.to_string(),
                    case_sensitive: false,
                    full_match: false,
                })),
            },
        )?;
        Ok(resp.row)
    }

    fn select_single(&self, grid_id: i64, row: i32, col: i32) -> Result<(), String> {
        let range = pb::CellRange {
            row1: row,
            col1: col,
            row2: row,
            col2: col,
        };
        let _: pb::SelectResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Select",
            &pb::SelectRequest {
                grid_id,
                active_row: row,
                active_col: col,
                ranges: vec![range],
                show: Some(true),
            },
        )?;
        Ok(())
    }

    fn show_cell(&self, grid_id: i64, row: i32, col: i32) -> Result<(), String> {
        let _: pb::ShowCellResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/ShowCell",
            &pb::ShowCellRequest { grid_id, row, col },
        )?;
        Ok(())
    }

    fn export(
        &self,
        grid_id: i64,
        format: pb::ExportFormat,
        scope: pb::ExportScope,
    ) -> Result<pb::ExportResponse, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Export",
            &pb::ExportRequest {
                grid_id,
                format: format as i32,
                scope: scope as i32,
            },
        )
    }

    fn load_data(&self, grid_id: i64, data: Vec<u8>) -> Result<pb::LoadDataResult, String> {
        self.load_data_with_options(grid_id, data, None)
    }

    fn load_data_with_options(
        &self,
        grid_id: i64,
        data: Vec<u8>,
        options: Option<pb::LoadDataOptions>,
    ) -> Result<pb::LoadDataResult, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/LoadData",
            &pb::LoadDataRequest {
                grid_id,
                data,
                options,
            },
        )
    }

    fn define_columns(&self, grid_id: i64, columns: Vec<pb::ColumnDef>) -> Result<(), String> {
        let _: pb::DefineColumnsResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/DefineColumns",
            &pb::DefineColumnsRequest { grid_id, columns },
        )?;
        Ok(())
    }

    fn define_rows(&self, grid_id: i64, rows: Vec<pb::RowDef>) -> Result<(), String> {
        let _: pb::DefineRowsResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/DefineRows",
            &pb::DefineRowsRequest { grid_id, rows },
        )?;
        Ok(())
    }

    fn update_cells(
        &self,
        grid_id: i64,
        cells: Vec<pb::CellUpdate>,
        atomic: bool,
    ) -> Result<(), String> {
        let _: pb::WriteResult = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/UpdateCells",
            &pb::UpdateCellsRequest {
                grid_id,
                cells,
                atomic,
            },
        )?;
        Ok(())
    }

    fn subtotal(
        &self,
        grid_id: i64,
        aggregate: pb::AggregateType,
        group_on_col: i32,
        aggregate_col: i32,
        caption: &str,
        background: u32,
        foreground: u32,
        add_outline: bool,
    ) -> Result<pb::SubtotalResult, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Subtotal",
            &pb::SubtotalRequest {
                grid_id,
                aggregate: aggregate as i32,
                group_on_col,
                aggregate_col,
                caption: caption.to_string(),
                background,
                foreground,
                add_outline,
                font: None,
            },
        )
    }

    fn clipboard_copy(&self, grid_id: i64) -> Result<pb::ClipboardResponse, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Clipboard",
            &pb::ClipboardCommand {
                grid_id,
                command: Some(pb::clipboard_command::Command::Copy(pb::ClipboardCopy {})),
            },
        )
    }

    fn clipboard_paste(&self, grid_id: i64, text: String) -> Result<(), String> {
        let _: pb::ClipboardResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Clipboard",
            &pb::ClipboardCommand {
                grid_id,
                command: Some(pb::clipboard_command::Command::Paste(pb::ClipboardPaste {
                    text,
                    rich_data: Vec::new(),
                })),
            },
        )?;
        Ok(())
    }

    fn insert_rows(&self, grid_id: i64, index: i32, count: i32) -> Result<(), String> {
        let _: pb::InsertRowsResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/InsertRows",
            &pb::InsertRowsRequest {
                grid_id,
                index,
                count,
                text: Vec::new(),
            },
        )?;
        Ok(())
    }

    fn remove_rows(&self, grid_id: i64, index: i32, count: i32) -> Result<(), String> {
        let _: pb::RemoveRowsResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/RemoveRows",
            &pb::RemoveRowsRequest {
                grid_id,
                index,
                count,
            },
        )?;
        Ok(())
    }

    fn define_column_hidden(&self, grid_id: i64, index: i32, hidden: bool) -> Result<(), String> {
        let _: pb::DefineColumnsResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/DefineColumns",
            &pb::DefineColumnsRequest {
                grid_id,
                columns: vec![pb::ColumnDef {
                    index,
                    hidden: Some(hidden),
                    ..Default::default()
                }],
            },
        )?;
        Ok(())
    }

    fn auto_size(&self, grid_id: i64, from: i32, to: i32) -> Result<(), String> {
        let _: pb::AutoSizeResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/AutoSize",
            &pb::AutoSizeRequest {
                grid_id,
                col_from: from,
                col_to: to,
                equal: false,
                max_width: 320,
            },
        )?;
        Ok(())
    }

    fn print(&self, grid_id: i64) -> Result<pb::PrintResponse, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Print",
            &pb::PrintRequest {
                grid_id,
                orientation: Some(pb::PrintOrientation::PrintLandscape as i32),
                margin_left: Some(20),
                margin_top: Some(20),
                margin_right: Some(20),
                margin_bottom: Some(20),
                header: Some("VolvoxGrid GTK Test".to_string()),
                footer: Some("Plugin FFI".to_string()),
                show_page_numbers: Some(true),
            },
        )
    }

    fn get_memory_usage(&self, grid_id: i64) -> Result<pb::MemoryUsageResponse, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/GetMemoryUsage",
            &pb::GridHandle { id: grid_id },
        )
    }

    fn resize_viewport(&self, grid_id: i64, width: i32, height: i32) -> Result<(), String> {
        let _: pb::ResizeViewportResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/ResizeViewport",
            &pb::ResizeViewportRequest {
                grid_id,
                width,
                height,
            },
        )?;
        Ok(())
    }

    fn invoke<Req, Resp>(&self, method: &str, req: &Req) -> Result<Resp, String>
    where
        Req: Message,
        Resp: Message + Default,
    {
        let data = self.plugin.invoke_raw(method, &req.encode_to_vec())?;
        Resp::decode(data.as_slice()).map_err(|err| format!("decode failed for {method}: {err}"))
    }
}

fn apply_initial_config_for_grid(
    client: &VolvoxServiceClient,
    grid_id: i64,
    scroll_blit_enabled: bool,
) -> Result<(), String> {
    client.configure(
        grid_id,
        pb::GridConfig {
            rendering: Some(pb::RenderConfig {
                renderer_mode: Some(pb::RendererMode::RendererCpu as i32),
                animation_enabled: Some(true),
                frame_pacing_mode: Some(pb::FramePacingMode::Auto as i32),
                target_frame_rate_hz: Some(30),
                scroll_blit: Some(scroll_blit_enabled),
                ..Default::default()
            }),
            editing: Some(pb::EditConfig {
                host_key_dispatch: Some(false),
                host_pointer_dispatch: Some(false),
                ..Default::default()
            }),
            interaction: Some(pb::InteractionConfig {
                header_features: Some(pb::HeaderFeatures {
                    sort: Some(true),
                    reorder: Some(true),
                    chooser: Some(false),
                }),
                ..Default::default()
            }),
            ..Default::default()
        },
    )?;
    Ok(())
}

fn apply_initial_config(state: &mut State) -> Result<(), String> {
    apply_initial_config_for_grid(&state.client, state.grid_id, state.scroll_blit_enabled)
}

fn apply_host_runtime_config(state: &State, grid_id: i64) -> Result<(), String> {
    state.client.configure(
        grid_id,
        pb::GridConfig {
            rendering: Some(pb::RenderConfig {
                debug_overlay: Some(state.debug_overlay),
                frame_pacing_mode: Some(state.frame_pacing_mode),
                target_frame_rate_hz: Some(state.target_frame_rate_hz),
                render_layer_mask: Some(state.render_layer_mask as i64),
                scroll_blit: Some(state.scroll_blit_enabled),
                ..Default::default()
            }),
            selection: Some(pb::SelectionConfig {
                mode: Some(selection_mode_value(state.selection_mode_idx)),
                hover: Some(pb::HoverConfig {
                    row: Some(state.hover_enabled),
                    column: Some(state.hover_enabled),
                    cell: Some(state.hover_enabled),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            ..Default::default()
        },
    )?;
    Ok(())
}

fn sales_highlight_style(
    background: u32,
    foreground: Option<u32>,
    border_style: Option<i32>,
    border_color: Option<u32>,
) -> pb::HighlightStyle {
    pb::HighlightStyle {
        background: Some(background),
        foreground,
        borders: match (border_style, border_color) {
            (Some(style), Some(color)) => Some(pb::Borders {
                all: Some(pb::Border {
                    style: Some(style),
                    color: Some(color),
                }),
                ..Default::default()
            }),
            _ => None,
        },
        ..Default::default()
    }
}

fn sales_theme_config() -> pb::GridConfig {
    pb::GridConfig {
        layout: Some(pb::LayoutConfig {
            fixed_rows: Some(0),
            ..Default::default()
        }),
        style: Some(pb::StyleConfig {
            background: Some(0xFFFFFFFF),
            foreground: Some(0xFF111827),
            alternate_background: Some(0xFFF9FAFB),
            progress_color: Some(0xFF818CF8),
            sheet_background: Some(0xFFFAFAFB),
            sheet_border: Some(0xFFD1D5DB),
            grid_lines: Some(pb::GridLines {
                style: Some(pb::GridLineStyle::GridlineSolid as i32),
                color: Some(0xFFE5E7EB),
                ..Default::default()
            }),
            fixed: Some(pb::RegionStyle {
                background: Some(0xFFF3F4F6),
                foreground: Some(0xFF374151),
                grid_lines: Some(pb::GridLines {
                    style: Some(pb::GridLineStyle::GridlineSolid as i32),
                    color: Some(0xFFD1D5DB),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            frozen: Some(pb::RegionStyle {
                background: Some(0xFFFFFFFF),
                foreground: Some(0xFF111827),
                grid_lines: Some(pb::GridLines {
                    style: Some(pb::GridLineStyle::GridlineSolid as i32),
                    color: Some(0xFFD1D5DB),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            header: Some(pb::HeaderStyle {
                separator: Some(pb::HeaderSeparator {
                    enabled: Some(true),
                    color: Some(0xFFD1D5DB),
                    width: Some(1),
                    ..Default::default()
                }),
                resize_handle: Some(pb::HeaderResizeHandle {
                    enabled: Some(true),
                    color: Some(0xFFD1D5DB),
                    width: Some(1),
                    hit_width: Some(6),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            ..Default::default()
        }),
        selection: Some(pb::SelectionConfig {
            mode: Some(pb::SelectionMode::SelectionFree as i32),
            style: Some(pb::HighlightStyle {
                background: Some(0xFF6366F1),
                foreground: Some(0xFFFFFFFF),
                fill_handle: Some(pb::FillHandlePosition::FillHandleNone as i32),
                fill_handle_color: Some(0xFF818CF8),
                ..Default::default()
            }),
            active_cell_style: Some(sales_highlight_style(
                0x22000000,
                Some(0xFFFFFFFF),
                Some(pb::BorderStyle::BorderThick as i32),
                Some(0xFF818CF8),
            )),
            hover: Some(pb::HoverConfig {
                row: Some(true),
                column: Some(true),
                cell: Some(true),
                row_style: Some(sales_highlight_style(0x106366F1, None, None, None)),
                column_style: Some(sales_highlight_style(0x106366F1, None, None, None)),
                cell_style: Some(sales_highlight_style(
                    0x1E818CF8,
                    None,
                    Some(pb::BorderStyle::BorderThin as i32),
                    Some(0xFF818CF8),
                )),
            }),
            ..Default::default()
        }),
        editing: Some(pb::EditConfig {
            trigger: Some(pb::EditTrigger::None as i32),
            tab_behavior: Some(pb::TabBehavior::TabCells as i32),
            dropdown_trigger: Some(pb::DropdownTrigger::DropdownAlways as i32),
            dropdown_search: Some(false),
            ..Default::default()
        }),
        scrolling: Some(pb::ScrollConfig {
            scrollbars: Some(pb::ScrollBarsMode::ScrollbarBoth as i32),
            fling_enabled: Some(true),
            fling_impulse_gain: Some(220.0),
            fling_friction: Some(0.9),
            ..Default::default()
        }),
        outline: Some(pb::OutlineConfig {
            tree_indicator: Some(pb::TreeIndicatorStyle::TreeIndicatorNone as i32),
            tree_color: Some(0xFF9CA3AF),
            group_total_position: Some(pb::GroupTotalPosition::GroupTotalBelow as i32),
            multi_totals: Some(true),
            ..Default::default()
        }),
        span: Some(pb::SpanConfig {
            cell_span: Some(pb::CellSpanMode::CellSpanAdjacent as i32),
            cell_span_fixed: Some(pb::CellSpanMode::CellSpanNone as i32),
            cell_span_compare: Some(1),
            ..Default::default()
        }),
        interaction: Some(pb::InteractionConfig {
            resize: Some(pb::ResizePolicy {
                columns: Some(true),
                rows: Some(true),
                ..Default::default()
            }),
            freeze: Some(pb::FreezePolicy {
                columns: Some(true),
                rows: Some(true),
                ..Default::default()
            }),
            auto_size_mouse: Some(true),
            header_features: Some(pb::HeaderFeatures {
                sort: Some(true),
                reorder: Some(true),
                chooser: Some(false),
            }),
            ..Default::default()
        }),
        indicators: Some(pb::IndicatorsConfig {
            row_start: Some(pb::RowIndicatorConfig {
                visible: Some(true),
                width: Some(40),
                mode_bits: Some(pb::RowIndicatorMode::RowIndicatorNumbers as u32),
                background: Some(0xFFF9FAFB),
                foreground: Some(0xFF6B7280),
                grid_color: Some(0xFFD1D5DB),
                allow_resize: Some(true),
                ..Default::default()
            }),
            col_top: Some(pb::ColIndicatorConfig {
                visible: Some(true),
                default_row_height: Some(28),
                band_rows: Some(1),
                mode_bits: Some(
                    (pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32)
                        | (pb::ColIndicatorCellMode::ColIndicatorCellSortGlyph as u32),
                ),
                background: Some(0xFFF9FAFB),
                foreground: Some(0xFF111827),
                grid_color: Some(0xFFD1D5DB),
                allow_resize: Some(true),
                ..Default::default()
            }),
            ..Default::default()
        }),
        ..Default::default()
    }
}

fn hierarchy_theme_config() -> pb::GridConfig {
    pb::GridConfig {
        layout: Some(pb::LayoutConfig {
            fixed_rows: Some(0),
            ..Default::default()
        }),
        style: Some(pb::StyleConfig {
            background: Some(0xFFFFFFFF),
            foreground: Some(0xFF1C1917),
            alternate_background: Some(0xFFF5F5F4),
            progress_color: Some(0xFFF59E0B),
            sheet_background: Some(0xFFFAFAF9),
            sheet_border: Some(0xFFD6D3D1),
            grid_lines: Some(pb::GridLines {
                style: Some(pb::GridLineStyle::GridlineSolid as i32),
                color: Some(0xFFE7E5E4),
                ..Default::default()
            }),
            fixed: Some(pb::RegionStyle {
                background: Some(0xFFF5F5F4),
                foreground: Some(0xFF44403C),
                grid_lines: Some(pb::GridLines {
                    style: Some(pb::GridLineStyle::GridlineSolid as i32),
                    color: Some(0xFFD6D3D1),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            frozen: Some(pb::RegionStyle {
                background: Some(0xFFFFFFFF),
                foreground: Some(0xFF1C1917),
                grid_lines: Some(pb::GridLines {
                    style: Some(pb::GridLineStyle::GridlineSolid as i32),
                    color: Some(0xFFD6D3D1),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            header: Some(pb::HeaderStyle {
                separator: Some(pb::HeaderSeparator {
                    enabled: Some(true),
                    color: Some(0xFFD6D3D1),
                    width: Some(1),
                    ..Default::default()
                }),
                resize_handle: Some(pb::HeaderResizeHandle {
                    enabled: Some(true),
                    color: Some(0xFFD6D3D1),
                    width: Some(1),
                    hit_width: Some(6),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            ..Default::default()
        }),
        selection: Some(pb::SelectionConfig {
            mode: Some(pb::SelectionMode::SelectionFree as i32),
            style: Some(pb::HighlightStyle {
                background: Some(0xFFD97706),
                foreground: Some(0xFFFFFFFF),
                fill_handle: Some(pb::FillHandlePosition::FillHandleNone as i32),
                fill_handle_color: Some(0xFFF59E0B),
                ..Default::default()
            }),
            active_cell_style: Some(sales_highlight_style(
                0x22000000,
                Some(0xFFFFFFFF),
                Some(pb::BorderStyle::BorderThick as i32),
                Some(0xFFF59E0B),
            )),
            hover: Some(pb::HoverConfig {
                cell: Some(true),
                cell_style: Some(sales_highlight_style(
                    0x1AD97706,
                    None,
                    Some(pb::BorderStyle::BorderThin as i32),
                    Some(0xFFF59E0B),
                )),
                ..Default::default()
            }),
            ..Default::default()
        }),
        editing: Some(pb::EditConfig {
            trigger: Some(pb::EditTrigger::None as i32),
            tab_behavior: Some(pb::TabBehavior::TabCells as i32),
            dropdown_trigger: Some(pb::DropdownTrigger::DropdownNever as i32),
            ..Default::default()
        }),
        scrolling: Some(pb::ScrollConfig {
            scrollbars: Some(pb::ScrollBarsMode::ScrollbarBoth as i32),
            fling_enabled: Some(true),
            fling_impulse_gain: Some(220.0),
            fling_friction: Some(0.9),
            ..Default::default()
        }),
        outline: Some(pb::OutlineConfig {
            tree_indicator: Some(pb::TreeIndicatorStyle::TreeIndicatorArrowsLeaf as i32),
            tree_column: Some(0),
            tree_color: Some(0xFFA8A29E),
            ..Default::default()
        }),
        interaction: Some(pb::InteractionConfig {
            resize: Some(pb::ResizePolicy {
                columns: Some(true),
                rows: Some(true),
                ..Default::default()
            }),
            freeze: Some(pb::FreezePolicy {
                columns: Some(true),
                rows: Some(true),
                ..Default::default()
            }),
            auto_size_mouse: Some(true),
            header_features: Some(pb::HeaderFeatures {
                sort: Some(false),
                reorder: Some(false),
                chooser: Some(false),
            }),
            ..Default::default()
        }),
        indicators: Some(pb::IndicatorsConfig {
            row_start: Some(pb::RowIndicatorConfig {
                visible: Some(false),
                ..Default::default()
            }),
            col_top: Some(pb::ColIndicatorConfig {
                visible: Some(true),
                default_row_height: Some(28),
                band_rows: Some(1),
                mode_bits: Some(pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32),
                background: Some(0xFFFAFAF9),
                foreground: Some(0xFF1C1917),
                grid_color: Some(0xFFD6D3D1),
                allow_resize: Some(true),
                ..Default::default()
            }),
            ..Default::default()
        }),
        ..Default::default()
    }
}

fn load_sales_json_demo(client: &VolvoxServiceClient, grid_id: i64) -> Result<(), String> {
    client.configure(
        grid_id,
        pb::GridConfig {
            layout: Some(pb::LayoutConfig {
                cols: Some(SALES_DEMO_COLS),
                ..Default::default()
            }),
            ..Default::default()
        },
    )?;
    client.define_columns(
        grid_id,
        vec![
            pb::ColumnDef {
                index: 0,
                width: Some(40),
                caption: Some("Q".to_string()),
                key: Some("Q".to_string()),
                align: Some(pb::Align::CenterCenter as i32),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 1,
                width: Some(80),
                caption: Some("Region".to_string()),
                key: Some("Region".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 2,
                width: Some(100),
                caption: Some("Category".to_string()),
                key: Some("Category".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 3,
                width: Some(120),
                caption: Some("Product".to_string()),
                key: Some("Product".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 4,
                width: Some(90),
                caption: Some("Sales".to_string()),
                key: Some("Sales".to_string()),
                align: Some(pb::Align::RightCenter as i32),
                data_type: Some(pb::ColumnDataType::ColumnDataCurrency as i32),
                format: Some("$#,##0".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 5,
                width: Some(90),
                caption: Some("Cost".to_string()),
                key: Some("Cost".to_string()),
                align: Some(pb::Align::RightCenter as i32),
                data_type: Some(pb::ColumnDataType::ColumnDataCurrency as i32),
                format: Some("$#,##0".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 6,
                width: Some(70),
                caption: Some("Margin%".to_string()),
                key: Some("Margin".to_string()),
                align: Some(pb::Align::CenterCenter as i32),
                data_type: Some(pb::ColumnDataType::ColumnDataNumber as i32),
                progress_color: Some(0xFF818CF8),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 7,
                width: Some(56),
                caption: Some("Flag".to_string()),
                key: Some("Flag".to_string()),
                align: Some(pb::Align::CenterCenter as i32),
                data_type: Some(pb::ColumnDataType::ColumnDataBoolean as i32),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 8,
                width: Some(80),
                caption: Some("Status".to_string()),
                key: Some("Status".to_string()),
                dropdown_items: Some(SALES_STATUS_ITEMS.to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 9,
                width: Some(140),
                caption: Some("Notes".to_string()),
                key: Some("Notes".to_string()),
                ..Default::default()
            },
        ],
    )?;
    let result = client.load_data_with_options(
        grid_id,
        client.get_demo_data(DEMO_SALES)?,
        Some(pb::LoadDataOptions {
            auto_create_columns: Some(false),
            ..Default::default()
        }),
    )?;
    if result.status == pb::LoadDataStatus::LoadFailed as i32 {
        return Err("LoadData failed for embedded sales demo".to_string());
    }
    client.define_columns(
        grid_id,
        vec![
            pb::ColumnDef {
                index: 7,
                align: Some(pb::Align::CenterCenter as i32),
                data_type: Some(pb::ColumnDataType::ColumnDataBoolean as i32),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 8,
                dropdown_items: Some(SALES_STATUS_ITEMS.to_string()),
                ..Default::default()
            },
        ],
    )?;
    client.configure(grid_id, sales_theme_config())?;

    client.subtotal(grid_id, pb::AggregateType::AggClear, 0, 0, "", 0, 0, false)?;
    apply_sales_subtotal_decorations(
        client,
        grid_id,
        &client.subtotal(
            grid_id,
            pb::AggregateType::AggSum,
            -1,
            4,
            "Grand Total",
            0xFFEEF2FF,
            0xFF111827,
            true,
        )?,
    )?;
    apply_sales_subtotal_decorations(
        client,
        grid_id,
        &client.subtotal(
            grid_id,
            pb::AggregateType::AggSum,
            0,
            4,
            "",
            0xFFF5F3FF,
            0xFF111827,
            true,
        )?,
    )?;
    apply_sales_subtotal_decorations(
        client,
        grid_id,
        &client.subtotal(
            grid_id,
            pb::AggregateType::AggSum,
            1,
            4,
            "",
            0xFFF8F7FF,
            0xFF111827,
            true,
        )?,
    )?;
    apply_sales_subtotal_decorations(
        client,
        grid_id,
        &client.subtotal(
            grid_id,
            pb::AggregateType::AggSum,
            -1,
            5,
            "Grand Total",
            0xFFEEF2FF,
            0xFF111827,
            true,
        )?,
    )?;
    apply_sales_subtotal_decorations(
        client,
        grid_id,
        &client.subtotal(
            grid_id,
            pb::AggregateType::AggSum,
            0,
            5,
            "",
            0xFFF5F3FF,
            0xFF111827,
            true,
        )?,
    )?;
    apply_sales_subtotal_decorations(
        client,
        grid_id,
        &client.subtotal(
            grid_id,
            pb::AggregateType::AggSum,
            1,
            5,
            "",
            0xFFF8F7FF,
            0xFF111827,
            true,
        )?,
    )?;
    Ok(())
}

fn apply_sales_subtotal_decorations(
    client: &VolvoxServiceClient,
    grid_id: i64,
    result: &pb::SubtotalResult,
) -> Result<(), String> {
    client.define_columns(
        grid_id,
        vec![
            pb::ColumnDef {
                index: 0,
                span: Some(true),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 1,
                span: Some(true),
                ..Default::default()
            },
        ],
    )?;

    let mut unique_rows = result.rows.clone();
    unique_rows.sort_unstable();
    unique_rows.dedup();
    for row in unique_rows {
        if client.get_node(grid_id, row)?.level <= 0 {
            client.merge_cells(grid_id, row, 0, row, 1)?;
        }
    }
    Ok(())
}

fn load_hierarchy_json_demo(client: &VolvoxServiceClient, grid_id: i64) -> Result<(), String> {
    client.configure(
        grid_id,
        pb::GridConfig {
            layout: Some(pb::LayoutConfig {
                cols: Some(HIERARCHY_DEMO_COLS),
                ..Default::default()
            }),
            ..Default::default()
        },
    )?;
    let raw_json = client.get_demo_data(DEMO_HIERARCHY)?;
    let rows: Vec<HierarchyJsonRow> = serde_json::from_slice(&raw_json)
        .map_err(|err| format!("embedded hierarchy demo parse failed: {err}"))?;
    let load_rows: Vec<HierarchyLoadRow<'_>> = rows
        .iter()
        .map(|row| HierarchyLoadRow {
            name: &row.name,
            kind: &row.kind,
            size: &row.size,
            modified: &row.modified,
            permissions: &row.permissions,
            action: &row.action,
        })
        .collect();
    let load_data = serde_json::to_vec(&load_rows)
        .map_err(|err| format!("embedded hierarchy demo encode failed: {err}"))?;
    client.define_columns(
        grid_id,
        vec![
            pb::ColumnDef {
                index: 0,
                width: Some(260),
                caption: Some("Name".to_string()),
                key: Some("Name".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 1,
                width: Some(80),
                caption: Some("Type".to_string()),
                key: Some("Type".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 2,
                width: Some(80),
                caption: Some("Size".to_string()),
                key: Some("Size".to_string()),
                align: Some(pb::Align::RightCenter as i32),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 3,
                width: Some(120),
                caption: Some("Modified".to_string()),
                key: Some("Modified".to_string()),
                data_type: Some(pb::ColumnDataType::ColumnDataDate as i32),
                format: Some("short date".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 4,
                width: Some(100),
                caption: Some("Permissions".to_string()),
                key: Some("Permissions".to_string()),
                align: Some(pb::Align::CenterCenter as i32),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 5,
                width: Some(92),
                caption: Some("Action".to_string()),
                key: Some("Action".to_string()),
                align: Some(pb::Align::CenterCenter as i32),
                interaction: Some(pb::CellInteraction::TextLink as i32),
                ..Default::default()
            },
        ],
    )?;
    let result = client.load_data_with_options(
        grid_id,
        load_data,
        Some(pb::LoadDataOptions {
            auto_create_columns: Some(false),
            ..Default::default()
        }),
    )?;
    if result.status == pb::LoadDataStatus::LoadFailed as i32 {
        return Err("LoadData failed for embedded hierarchy demo".to_string());
    }

    client.configure(grid_id, hierarchy_theme_config())?;

    client.define_rows(
        grid_id,
        rows.iter()
            .enumerate()
            .map(|(index, row)| pb::RowDef {
                index: index as i32,
                outline_level: Some(row.level),
                is_subtotal: Some(row.kind == "Folder"),
                ..Default::default()
            })
            .collect(),
    )?;

    let action_style = pb::CellStyle {
        foreground: Some(0xFF2563EB),
        ..Default::default()
    };
    let folder_style = pb::CellStyle {
        foreground: Some(0xFF92400E),
        font: Some(pb::Font {
            bold: Some(true),
            ..Default::default()
        }),
        ..Default::default()
    };
    let mut cells = Vec::with_capacity(rows.len() * 2);
    for (index, row) in rows.iter().enumerate() {
        cells.push(pb::CellUpdate {
            row: index as i32,
            col: 5,
            style: Some(action_style.clone()),
            ..Default::default()
        });
        if row.kind == "Folder" {
            cells.push(pb::CellUpdate {
                row: index as i32,
                col: 0,
                style: Some(folder_style.clone()),
                ..Default::default()
            });
        }
    }
    client.update_cells(grid_id, cells, true)?;
    Ok(())
}

fn ensure_demo_grid(state: &mut State, demo: &str) -> Result<(i64, bool), String> {
    if let Some(&grid_id) = state.grid_sessions.get(demo) {
        return Ok((grid_id, false));
    }

    let width = if state.viewport_width > 0 {
        state.viewport_width
    } else {
        DEFAULT_WIDTH
    };
    let height = if state.viewport_height > 0 {
        state.viewport_height
    } else {
        DEFAULT_HEIGHT
    };
    let create = state.client.create_grid(width, height)?;
    let grid_id = create
        .handle
        .map(|handle| handle.id)
        .ok_or_else(|| "plugin returned no grid handle".to_string())?;
    apply_initial_config_for_grid(&state.client, grid_id, state.scroll_blit_enabled)?;
    state.grid_sessions.insert(demo.to_string(), grid_id);
    Ok((grid_id, true))
}

fn attach_grid_session(state: &mut State, grid_id: i64) -> Result<(), String> {
    let new_render_stream = state.client.open_render_session()?;
    let new_event_stream = state.client.open_event_stream(grid_id)?;
    let next_epoch = state.stream_epoch + 1;

    spawn_render_output_thread(
        Arc::clone(&new_render_stream),
        state.sender.clone(),
        next_epoch,
    );
    spawn_grid_event_thread(
        Arc::clone(&new_event_stream),
        state.sender.clone(),
        next_epoch,
    );

    let old_render_stream = std::mem::replace(&mut state.render_stream, new_render_stream);
    let old_event_stream = std::mem::replace(&mut state.event_stream, new_event_stream);
    old_render_stream.close();
    old_event_stream.close();

    state.stream_epoch = next_epoch;
    state.grid_id = grid_id;
    state.frame_in_flight = false;
    state.frame_awaiting_present = false;
    state.needs_followup_frame = false;
    state.followup_frame_scheduled = false;
    state.followup_schedule_seq = state.followup_schedule_seq.wrapping_add(1);
    state.pending_resize = None;
    state.inflight_target = None;
    state.spare_target = None;
    state.selection = pb::SelectionState::default();
    state.event_count = 0;
    state.last_event = "(none)".to_string();
    state.edit_overlay_cell = None;
    Ok(())
}

fn switch_demo_session(
    state: &mut State,
    demo: &'static str,
    btn_sales: &Button,
    btn_hierarchy: &Button,
    btn_stress: &Button,
) -> Result<String, String> {
    if state.current_demo == demo {
        return Ok(format!("Already on {demo} demo"));
    }

    let (grid_id, created) = ensure_demo_grid(state, demo)?;
    if grid_id != state.grid_id {
        attach_grid_session(state, grid_id)?;
    }
    if created {
        if demo == DEMO_SALES {
            load_sales_json_demo(&state.client, grid_id)?;
        } else if demo == DEMO_HIERARCHY {
            load_hierarchy_json_demo(&state.client, grid_id)?;
        } else {
            state.client.load_demo(grid_id, demo)?;
        }
    }
    apply_host_runtime_config(state, grid_id)?;
    state.client.refresh(grid_id)?;

    state.current_demo = demo.to_string();
    state.col_hidden = false;
    state.engine_editing = false;
    set_demo_button_active(btn_sales, demo == DEMO_SALES);
    set_demo_button_active(btn_hierarchy, demo == DEMO_HIERARCHY);
    set_demo_button_active(btn_stress, demo == DEMO_STRESS);

    Ok(if created {
        format!("Created {demo} demo (grid {grid_id})")
    } else {
        format!("Switched to {demo} demo (grid {grid_id})")
    })
}

fn spawn_render_output_thread(stream: Arc<PluginStream>, sender: UiMessageSender, epoch: u64) {
    std::thread::spawn(move || loop {
        match stream.recv_raw() {
            Ok(Some(data)) => match pb::RenderOutput::decode(data.as_slice()) {
                Ok(output) => {
                    if !sender.send(UiMessage::RenderOutput(epoch, output)) {
                        break;
                    }
                }
                Err(err) => {
                    let _ = sender.send(UiMessage::StreamError(
                        epoch,
                        "render",
                        format!("decode RenderOutput failed: {err}"),
                    ));
                    break;
                }
            },
            Ok(None) => {
                let _ = sender.send(UiMessage::StreamEnded(epoch, "render"));
                break;
            }
            Err(err) => {
                let _ = sender.send(UiMessage::StreamError(epoch, "render", err));
                break;
            }
        }
    });
}

fn spawn_grid_event_thread(stream: Arc<PluginStream>, sender: UiMessageSender, epoch: u64) {
    std::thread::spawn(move || loop {
        match stream.recv_raw() {
            Ok(Some(data)) => match pb::GridEvent::decode(data.as_slice()) {
                Ok(event) => {
                    if !sender.send(UiMessage::GridEvent(epoch, event)) {
                        break;
                    }
                }
                Err(err) => {
                    let _ = sender.send(UiMessage::StreamError(
                        epoch,
                        "events",
                        format!("decode GridEvent failed: {err}"),
                    ));
                    break;
                }
            },
            Ok(None) => {
                let _ = sender.send(UiMessage::StreamEnded(epoch, "events"));
                break;
            }
            Err(err) => {
                let _ = sender.send(UiMessage::StreamError(epoch, "events", err));
                break;
            }
        }
    });
}

fn attach_ui_message_pump(
    state: Rc<RefCell<State>>,
    area: DrawingArea,
    edit_entry: Entry,
    dropdown_combo: ComboBoxText,
    dropdown_combo_editable: ComboBoxText,
    status_label: Label,
    receiver: UiMessageReceiver,
) {
    let UiMessageReceiver {
        receiver,
        wake_pipe,
    } = receiver;
    let wake_fd = wake_pipe.read_fd();
    glib::source::unix_fd_add_local(
        wake_fd,
        glib::IOCondition::IN | glib::IOCondition::ERR | glib::IOCondition::HUP,
        move |_fd, _condition| {
            wake_pipe.drain();

            let mut needs_redraw = false;
            loop {
                match receiver.try_recv() {
                    Ok(msg) => {
                        needs_redraw |= process_ui_message(
                            &state,
                            &area,
                            &edit_entry,
                            &dropdown_combo,
                            &dropdown_combo_editable,
                            &status_label,
                            msg,
                        );
                    }
                    Err(mpsc::TryRecvError::Empty) => break,
                    Err(mpsc::TryRecvError::Disconnected) => {
                        if needs_redraw {
                            area.queue_draw();
                        }
                        return glib::ControlFlow::Break;
                    }
                }
            }
            if needs_redraw {
                area.queue_draw();
            }
            glib::ControlFlow::Continue
        },
    );
}

fn process_ui_message(
    state: &Rc<RefCell<State>>,
    area: &DrawingArea,
    edit_entry: &Entry,
    dropdown_combo: &ComboBoxText,
    dropdown_combo_editable: &ComboBoxText,
    status_label: &Label,
    msg: UiMessage,
) -> bool {
    let mut needs_redraw = false;
    let mut schedule_followup = false;
    {
        let mut st = state.borrow_mut();
        match msg {
            UiMessage::RenderOutput(epoch, output) => {
                if epoch != st.stream_epoch {
                    return false;
                }
                match handle_render_output(
                    &mut st,
                    &output,
                    area,
                    edit_entry,
                    dropdown_combo,
                    dropdown_combo_editable,
                ) {
                    Ok((redraw, followup)) => {
                        needs_redraw = redraw;
                        schedule_followup = followup;
                    }
                    Err(err) => st.status_note = format!("Render output failed: {err}"),
                }
            }
            UiMessage::GridEvent(epoch, event) => {
                if epoch != st.stream_epoch {
                    return false;
                }
                st.event_count += 1;
                st.last_event = grid_event_name(&event).to_string();
                if is_hierarchy_action_text_click(&st, &event) {
                    if let Some(pb::grid_event::Event::Click(click)) = event.event.as_ref() {
                        st.status_note = format!(
                            "Hierarchy action click: row {}, col {}, hit_area {}, interaction {}",
                            click.row + 1,
                            click.col,
                            click.hit_area,
                            click.interaction
                        );
                    }
                }
                // Track engine edit state for IME support.
                match &event.event {
                    Some(pb::grid_event::Event::StartEdit(_)) => {
                        st.engine_editing = true;
                    }
                    Some(pb::grid_event::Event::AfterEdit(_)) => {
                        st.engine_editing = false;
                    }
                    _ => {}
                }
            }
            UiMessage::StreamEnded(epoch, kind) => {
                if epoch != st.stream_epoch {
                    return false;
                }
                st.status_note = format!("{kind} stream ended");
            }
            UiMessage::StreamError(epoch, kind, err) => {
                if epoch != st.stream_epoch {
                    return false;
                }
                st.status_note = format!("{kind} stream error: {err}");
            }
        }
        update_status_label(&st, status_label);
    }
    if schedule_followup {
        schedule_followup_frame(state, area);
    }
    needs_redraw
}

fn handle_render_output(
    state: &mut State,
    output: &pb::RenderOutput,
    area: &DrawingArea,
    edit_entry: &Entry,
    dropdown_combo: &ComboBoxText,
    dropdown_combo_editable: &ComboBoxText,
) -> Result<(bool, bool), String> {
    let mut needs_redraw = false;
    let mut schedule_followup = false;
    let mut gpu_present_path = false;
    if let Some(event) = &output.event {
        match event {
            pb::render_output::Event::FrameDone(frame) => {
                state.frame_in_flight = false;
                if output.rendered {
                    if complete_frame_target(state, frame.handle) {
                        // Keep CPU presentation one frame behind rendering so
                        // fast partial-scroll frames do not overtake GTK paint.
                        state.frame_awaiting_present = true;
                        state.needs_followup_frame = true;
                        needs_redraw = true;
                    }
                } else {
                    retire_unrendered_inflight_target(state, frame.handle);
                }
            }
            pb::render_output::Event::Selection(selection) => {
                state.selection.active_row = selection.active_row;
                state.selection.active_col = selection.active_col;
                state.selection.ranges = selection.ranges.clone();
                if let Some((row, col)) = state.edit_overlay_cell {
                    if row != selection.active_row || col != selection.active_col {
                        hide_host_editors(edit_entry, dropdown_combo, dropdown_combo_editable);
                        state.edit_overlay_cell = None;
                    }
                }
            }
            pb::render_output::Event::Cursor(cursor) => {
                let name = match cursor.cursor {
                    x if x == pb::cursor_change::CursorType::ResizeCol as i32 => Some("col-resize"),
                    x if x == pb::cursor_change::CursorType::ResizeRow as i32 => Some("row-resize"),
                    x if x == pb::cursor_change::CursorType::MoveCol as i32 => Some("grab"),
                    x if x == pb::cursor_change::CursorType::Text as i32 => Some("text"),
                    x if x == pb::cursor_change::CursorType::Hand as i32 => Some("pointer"),
                    _ => Some("default"),
                };
                area.set_cursor_from_name(name);
            }
            pb::render_output::Event::EditRequest(_request) => {
                // Don't show the host GtkEntry overlay. The engine renders the
                // editor itself in the canvas and the IMContext on the drawing
                // area handles text input (including CJK composition). Showing
                // the overlay would steal focus from the drawing area and break
                // IME support.
                state.engine_editing = true;
            }
            pb::render_output::Event::DropdownRequest(request) => {
                show_combo_overlay(
                    state,
                    edit_entry,
                    dropdown_combo,
                    dropdown_combo_editable,
                    request,
                )?;
            }
            pb::render_output::Event::TooltipRequest(request) => {
                area.set_tooltip_text(Some(&request.text));
            }
            pb::render_output::Event::GpuFrameDone(_) => {
                state.frame_in_flight = false;
                gpu_present_path = true;
            }
        }
    }

    if output.rendered && gpu_present_path {
        schedule_followup = true;
    }

    Ok((needs_redraw, schedule_followup))
}

fn complete_frame_target(state: &mut State, handle: i64) -> bool {
    if let Some(mut target) = state.inflight_target.take() {
        if target.render_handle() != handle {
            state.inflight_target = Some(target);
            return false;
        }
        if target.blit_render_to_surface().is_err() {
            return false;
        }
        let previous_display = state.display_target.replace(target);
        state.spare_target = previous_display;
        return true;
    }

    false
}

fn retire_unrendered_inflight_target(state: &mut State, handle: i64) -> bool {
    if state
        .inflight_target
        .as_ref()
        .is_some_and(|target| target.render_handle() == handle)
    {
        if let Some(target) = state.inflight_target.take() {
            state.pending_resize = Some((target.width, target.height));
            state.spare_target = Some(target);
            return true;
        }
    }
    false
}

fn take_frame_target(state: &mut State, width: i32, height: i32) -> Result<FrameTarget, String> {
    if let Some(target) = state.spare_target.take() {
        if target.width == width && target.height == height {
            return Ok(target);
        }
    }
    FrameTarget::new(width, height)
}

fn request_frame(state: &mut State) -> Result<(), String> {
    state.followup_schedule_seq = state.followup_schedule_seq.wrapping_add(1);
    state.followup_frame_scheduled = false;

    let (width, height) = match state.pending_resize.take() {
        Some((w, h)) => (w.max(1), h.max(1)),
        None => (state.viewport_width.max(1), state.viewport_height.max(1)),
    };

    if width <= 0 || height <= 0 {
        return Ok(());
    }

    if state.frame_in_flight || state.frame_awaiting_present {
        state.needs_followup_frame = true;
        return Ok(());
    }

    let needs_resize = match state.display_target.as_ref() {
        Some(target) => target.width != width || target.height != height,
        None => true,
    };

    let mut target = take_frame_target(state, width, height)?;
    if state.scroll_blit_enabled && !needs_resize {
        if let Some(display) = state.display_target.as_ref() {
            target.copy_render_from(display);
        }
    }

    let (handle, stride) = if needs_resize {
        state.viewport_width = width;
        state.viewport_height = height;
        state.client.resize_viewport(state.grid_id, width, height)?;
        let handle = target.render_handle();
        let stride = target.stride();
        state.inflight_target = Some(target);
        (handle, stride)
    } else {
        let handle = target.render_handle();
        let stride = target.stride();
        state.inflight_target = Some(target);
        (handle, stride)
    };

    let ready = pb::RenderInput {
        grid_id: state.grid_id,
        input: Some(pb::render_input::Input::Buffer(pb::BufferReady {
            handle,
            capacity: stride * height,
            stride,
            width,
            height,
        })),
    };
    state.render_stream.send_raw(&ready.encode_to_vec())?;
    state.frame_in_flight = true;
    if state.needs_followup_frame {
        state.needs_followup_frame = false;
    }
    Ok(())
}

fn normalized_target_frame_rate_hz(target_hz: i32) -> i32 {
    if target_hz <= 0 {
        30
    } else {
        target_hz
    }
}

fn run_scheduled_followup_frame(state: &Rc<RefCell<State>>, seq: u64) {
    let mut st = state.borrow_mut();
    if seq != st.followup_schedule_seq {
        return;
    }
    st.followup_frame_scheduled = false;
    let _ = request_frame(&mut st);
}

fn schedule_followup_frame(state: &Rc<RefCell<State>>, area: &DrawingArea) {
    let (mode, target_hz, seq) = {
        let mut st = state.borrow_mut();
        if st.followup_frame_scheduled {
            return;
        }
        st.followup_frame_scheduled = true;
        (
            st.frame_pacing_mode,
            normalized_target_frame_rate_hz(st.target_frame_rate_hz),
            st.followup_schedule_seq,
        )
    };

    let mode_auto = pb::FramePacingMode::Auto as i32;
    let mode_platform = pb::FramePacingMode::Platform as i32;
    let mode_unlimited = pb::FramePacingMode::Unlimited as i32;
    let mode_fixed = pb::FramePacingMode::Fixed as i32;

    if mode == mode_unlimited {
        run_scheduled_followup_frame(state, seq);
        return;
    }

    if mode == mode_fixed {
        let state = Rc::clone(state);
        glib::timeout_add_local_once(Duration::from_secs_f64(1.0 / target_hz as f64), move || {
            run_scheduled_followup_frame(&state, seq)
        });
        return;
    }

    if mode == mode_auto || mode == mode_platform {
        let state = Rc::clone(state);
        area.add_tick_callback(move |_, _| {
            run_scheduled_followup_frame(&state, seq);
            glib::ControlFlow::Break
        });
        return;
    }

    run_scheduled_followup_frame(state, seq);
}

fn send_pointer_input(
    state: &mut State,
    kind: pb::pointer_event::Type,
    x: f32,
    y: f32,
    modifier: i32,
    button: i32,
    dbl_click: bool,
) -> Result<(), String> {
    let input = pb::RenderInput {
        grid_id: state.grid_id,
        input: Some(pb::render_input::Input::Pointer(pb::PointerEvent {
            r#type: kind as i32,
            x,
            y,
            modifier,
            button,
            dbl_click,
        })),
    };
    state.render_stream.send_raw(&input.encode_to_vec())?;
    Ok(())
}

fn send_scroll_input(state: &mut State, dx: f32, dy: f32) -> Result<(), String> {
    let input = pb::RenderInput {
        grid_id: state.grid_id,
        input: Some(pb::render_input::Input::Scroll(pb::ScrollEvent {
            delta_x: dx,
            delta_y: dy,
        })),
    };
    state.render_stream.send_raw(&input.encode_to_vec())?;
    Ok(())
}

fn send_key_input(
    state: &mut State,
    kind: pb::key_event::Type,
    key_code: i32,
    modifier: i32,
    character: String,
) -> Result<(), String> {
    let input = pb::RenderInput {
        grid_id: state.grid_id,
        input: Some(pb::render_input::Input::Key(pb::KeyEvent {
            r#type: kind as i32,
            key_code,
            modifier,
            character,
        })),
    };
    state.render_stream.send_raw(&input.encode_to_vec())?;
    Ok(())
}

fn show_edit_overlay(
    state: &mut State,
    edit_entry: &Entry,
    dropdown_combo: &ComboBoxText,
    dropdown_combo_editable: &ComboBoxText,
    request: &pb::EditRequest,
) {
    hide_combo_overlay(dropdown_combo);
    hide_combo_overlay(dropdown_combo_editable);
    state.suppress_entry_changed = true;
    state.edit_overlay_cell = Some((request.row, request.col));
    edit_entry.set_text(&request.current_value);
    edit_entry.set_position(request.current_value.chars().count() as i32);
    edit_entry.set_max_length(request.max_length.max(0));
    edit_entry.set_width_request(request.width.max(1.0).round() as i32);
    edit_entry.set_height_request(request.height.max(1.0).round() as i32);
    edit_entry.set_margin_start(request.x.max(0.0).round() as i32);
    edit_entry.set_margin_top(request.y.max(0.0).round() as i32);
    edit_entry.set_visible(true);
    edit_entry.grab_focus();
    state.suppress_entry_changed = false;
}

fn hide_host_editors(
    edit_entry: &Entry,
    dropdown_combo: &ComboBoxText,
    dropdown_combo_editable: &ComboBoxText,
) {
    edit_entry.set_visible(false);
    hide_combo_overlay(dropdown_combo);
    hide_combo_overlay(dropdown_combo_editable);
}

#[allow(deprecated)]
fn hide_combo_overlay(combo: &ComboBoxText) {
    combo.popdown();
    combo.set_visible(false);
}

fn combo_entry_widget(combo: &ComboBoxText) -> Option<Entry> {
    combo
        .child()
        .and_then(|child| child.downcast::<Entry>().ok())
}

#[allow(deprecated)]
fn show_combo_overlay(
    _state: &mut State,
    edit_entry: &Entry,
    dropdown_combo: &ComboBoxText,
    dropdown_combo_editable: &ComboBoxText,
    _request: &pb::DropdownRequest,
) -> Result<(), String> {
    // Let the engine render and handle the active dropdown list.
    hide_host_editors(edit_entry, dropdown_combo, dropdown_combo_editable);
    _state.edit_overlay_cell = None;
    Ok(())
}

fn commit_combo_selection(
    state: &Rc<RefCell<State>>,
    area: &DrawingArea,
    status: &Label,
    edit_entry: &Entry,
    dropdown_combo: &ComboBoxText,
    dropdown_combo_editable: &ComboBoxText,
    editable: bool,
) {
    let active_widget = if editable {
        dropdown_combo_editable
    } else {
        dropdown_combo
    };
    if !active_widget.is_visible() {
        return;
    }

    let text = active_widget
        .active_text()
        .map(|value| value.to_string())
        .or_else(|| {
            combo_entry_widget(dropdown_combo_editable).map(|entry| entry.text().to_string())
        })
        .unwrap_or_default();

    let Ok(mut st) = state.try_borrow_mut() else {
        return;
    };
    if st.suppress_combo_changed || !active_widget.is_visible() {
        return;
    }
    st.status_note = match st.client.edit_commit(st.grid_id, text) {
        Ok(()) => {
            hide_host_editors(edit_entry, dropdown_combo, dropdown_combo_editable);
            area.grab_focus();
            "Combo committed".to_string()
        }
        Err(err) => format!("Error: {err}"),
    };
    let _ = request_frame(&mut st);
    update_status_label(&st, status);
    drop(st);
}

fn handle_combo_key(
    state: &Rc<RefCell<State>>,
    area: &DrawingArea,
    status: &Label,
    edit_entry: &Entry,
    dropdown_combo: &ComboBoxText,
    dropdown_combo_editable: &ComboBoxText,
    keyval: gdk::Key,
    modifier: gdk::ModifierType,
    editable: bool,
) -> glib::Propagation {
    let key_code = gdk_keyval_to_vk(keyval);
    if key_code != 27 && key_code != 9 && key_code != 13 {
        return glib::Propagation::Proceed;
    }

    let active_widget = if editable {
        dropdown_combo_editable
    } else {
        dropdown_combo
    };
    if !active_widget.is_visible() {
        return glib::Propagation::Proceed;
    }

    let text = if editable {
        combo_entry_widget(dropdown_combo_editable)
            .map(|entry| entry.text().to_string())
            .unwrap_or_default()
    } else {
        active_widget
            .active_text()
            .map(|value| value.to_string())
            .unwrap_or_default()
    };

    run_action(state, area, status, |st| {
        if key_code == 27 {
            st.client.edit_cancel(st.grid_id)?;
            hide_host_editors(edit_entry, dropdown_combo, dropdown_combo_editable);
            area.grab_focus();
            return Ok("Combo canceled".to_string());
        }

        st.client.edit_commit(
            st.grid_id,
            truncated_text(&text, current_edit_max_length(st)),
        )?;
        hide_host_editors(edit_entry, dropdown_combo, dropdown_combo_editable);
        area.grab_focus();
        if key_code == 9 {
            let mods = gdk_modifier_to_flags(modifier);
            send_key_input(st, pb::key_event::Type::KeyDown, 9, mods, String::new())?;
        }
        Ok("Combo committed".to_string())
    });
    glib::Propagation::Stop
}

fn connect_demo_button(
    button: &Button,
    state: Rc<RefCell<State>>,
    area: DrawingArea,
    status: Label,
    edit_entry: Entry,
    dropdown_combo: ComboBoxText,
    dropdown_combo_editable: ComboBoxText,
    btn_sales: Button,
    btn_hierarchy: Button,
    btn_stress: Button,
    demo: &'static str,
) {
    button.connect_clicked(move |_| {
        hide_host_editors(&edit_entry, &dropdown_combo, &dropdown_combo_editable);
        run_action(&state, &area, &status, |st| {
            switch_demo_session(st, demo, &btn_sales, &btn_hierarchy, &btn_stress)
        });
    });
}

fn run_action<F>(state: &Rc<RefCell<State>>, _area: &DrawingArea, status: &Label, action: F)
where
    F: FnOnce(&mut State) -> Result<String, String>,
{
    let Ok(mut st) = state.try_borrow_mut() else {
        return;
    };
    st.status_note = match action(&mut st) {
        Ok(message) => message,
        Err(err) => format!("Error: {err}"),
    };
    let _ = request_frame(&mut st);
    update_status_label(&st, status);
    drop(st);
}

fn update_status_label(state: &State, label: &Label) {
    let row = state.selection.active_row + 1;
    let col = state.selection.active_col + 1;
    let ranges = state.selection.ranges.len();
    label.set_text(&format!(
        "Grid {} | Demo: {} | Pacing: {} | Cell: R{} C{} | Ranges: {} | Events: {} | Last: {} | {}",
        state.grid_id,
        state.current_demo,
        frame_pacing_status_text(state.frame_pacing_mode, state.target_frame_rate_hz),
        row.max(0),
        col.max(0),
        ranges,
        state.event_count,
        state.last_event,
        state.status_note
    ));
}

fn active_row(state: &State) -> i32 {
    state.selection.active_row.max(0)
}

fn active_col(state: &State) -> i32 {
    state.selection.active_col.max(0)
}

fn current_edit_max_length(_state: &State) -> i32 {
    4096
}

fn set_demo_button_active(button: &Button, active: bool) {
    if active {
        button.add_css_class("suggested-action");
        button.add_css_class("volvox-demo-active");
    } else {
        button.remove_css_class("suggested-action");
        button.remove_css_class("volvox-demo-active");
    }
}

fn grid_event_name(event: &pb::GridEvent) -> &'static str {
    match event.event.as_ref() {
        Some(pb::grid_event::Event::CellFocusChanging(_)) => "CellFocusChanging",
        Some(pb::grid_event::Event::CellFocusChanged(_)) => "CellFocusChanged",
        Some(pb::grid_event::Event::SelectionChanging(_)) => "SelectionChanging",
        Some(pb::grid_event::Event::SelectionChanged(_)) => "SelectionChanged",
        Some(pb::grid_event::Event::EnterCell(_)) => "EnterCell",
        Some(pb::grid_event::Event::LeaveCell(_)) => "LeaveCell",
        Some(pb::grid_event::Event::BeforeEdit(_)) => "BeforeEdit",
        Some(pb::grid_event::Event::StartEdit(_)) => "StartEdit",
        Some(pb::grid_event::Event::AfterEdit(_)) => "AfterEdit",
        Some(pb::grid_event::Event::CellEditValidate(_)) => "CellEditValidate",
        Some(pb::grid_event::Event::CellEditChange(_)) => "CellEditChange",
        Some(pb::grid_event::Event::BeforeSort(_)) => "BeforeSort",
        Some(pb::grid_event::Event::AfterSort(_)) => "AfterSort",
        Some(pb::grid_event::Event::BeforeScroll(_)) => "BeforeScroll",
        Some(pb::grid_event::Event::AfterScroll(_)) => "AfterScroll",
        Some(pb::grid_event::Event::MouseDown(_)) => "MouseDown",
        Some(pb::grid_event::Event::MouseUp(_)) => "MouseUp",
        Some(pb::grid_event::Event::MouseMove(_)) => "MouseMove",
        Some(pb::grid_event::Event::Click(_)) => "Click",
        Some(pb::grid_event::Event::DblClick(_)) => "DblClick",
        Some(pb::grid_event::Event::KeyDown(_)) => "KeyDown",
        Some(pb::grid_event::Event::KeyPress(_)) => "KeyPress",
        Some(pb::grid_event::Event::KeyUp(_)) => "KeyUp",
        Some(pb::grid_event::Event::CellChanged(_)) => "CellChanged",
        Some(pb::grid_event::Event::Error(_)) => "Error",
        Some(_) => "GridEvent",
        None => "GridEvent",
    }
}

fn is_hierarchy_action_text_click(state: &State, event: &pb::GridEvent) -> bool {
    if state.current_demo != DEMO_HIERARCHY {
        return false;
    }

    match event.event.as_ref() {
        Some(pb::grid_event::Event::Click(click)) => {
            click.row >= 0
                && click.col == 5
                && click.hit_area == pb::CellHitArea::HitText as i32
                && click.interaction == pb::CellInteraction::TextLink as i32
        }
        _ => false,
    }
}

fn selection_mode_value(index: u32) -> i32 {
    match index {
        1 => pb::SelectionMode::SelectionByRow as i32,
        2 => pb::SelectionMode::SelectionByColumn as i32,
        3 => pb::SelectionMode::SelectionListbox as i32,
        4 => pb::SelectionMode::SelectionMultiRange as i32,
        _ => pb::SelectionMode::SelectionFree as i32,
    }
}

fn frame_pacing_mode_value(index: u32) -> i32 {
    match index {
        1 => pb::FramePacingMode::Platform as i32,
        2 => pb::FramePacingMode::Unlimited as i32,
        3 => pb::FramePacingMode::Fixed as i32,
        _ => pb::FramePacingMode::Auto as i32,
    }
}

fn frame_pacing_dropdown_index(mode: i32) -> u32 {
    match mode {
        value if value == pb::FramePacingMode::Platform as i32 => 1,
        value if value == pb::FramePacingMode::Unlimited as i32 => 2,
        value if value == pb::FramePacingMode::Fixed as i32 => 3,
        _ => 0,
    }
}

fn sync_frame_pacing_widgets(mode: i32, fixed_label: &Label, fixed_hz: &SpinButton) {
    let fixed_visible = mode == pb::FramePacingMode::Fixed as i32;
    fixed_label.set_visible(fixed_visible);
    fixed_hz.set_visible(fixed_visible);
}

fn frame_pacing_status_text(mode: i32, target_hz: i32) -> String {
    match mode {
        value if value == pb::FramePacingMode::Platform as i32 => "Platform".to_string(),
        value if value == pb::FramePacingMode::Unlimited as i32 => "Unlimited".to_string(),
        value if value == pb::FramePacingMode::Fixed as i32 => {
            format!("Fixed {} Hz", normalized_target_frame_rate_hz(target_hz))
        }
        _ => "Auto".to_string(),
    }
}

fn set_system_clipboard_text(text: &str) {
    if let Some(display) = gdk::Display::default() {
        display.clipboard().set_text(text);
    }
}

fn truncated_text(text: &str, max_length: i32) -> String {
    if max_length <= 0 {
        return text.to_string();
    }
    text.chars().take(max_length as usize).collect()
}

fn rgba_to_bgra_copy(src: &[u8], dst: &mut [u8]) {
    for (src_px, dst_px) in src.chunks_exact(4).zip(dst.chunks_exact_mut(4)) {
        dst_px[0] = src_px[2];
        dst_px[1] = src_px[1];
        dst_px[2] = src_px[0];
        dst_px[3] = src_px[3];
    }
}

fn gdk_keyval_to_vk(keyval: gdk::Key) -> i32 {
    match keyval {
        gdk::Key::Shift_L | gdk::Key::Shift_R => 16,
        gdk::Key::Control_L | gdk::Key::Control_R => 17,
        gdk::Key::Alt_L | gdk::Key::Alt_R | gdk::Key::Meta_L | gdk::Key::Meta_R => 18,
        gdk::Key::Super_L | gdk::Key::Super_R => 91,
        gdk::Key::Left => 37,
        gdk::Key::Up => 38,
        gdk::Key::Right => 39,
        gdk::Key::Down => 40,
        gdk::Key::Page_Up => 33,
        gdk::Key::Page_Down => 34,
        gdk::Key::Home => 36,
        gdk::Key::End => 35,
        gdk::Key::space => 32,
        gdk::Key::Insert => 45,
        gdk::Key::Tab | gdk::Key::ISO_Left_Tab => 9,
        gdk::Key::Return | gdk::Key::KP_Enter => 13,
        gdk::Key::Delete => 46,
        gdk::Key::BackSpace => 8,
        gdk::Key::F2 => 113,
        gdk::Key::Escape => 27,
        _ => keyval
            .to_unicode()
            .map(|ch| ch.to_ascii_uppercase() as i32)
            .unwrap_or(0),
    }
}

fn gdk_modifier_to_flags(state: gdk::ModifierType) -> i32 {
    let mut flags = 0;
    if state.contains(gdk::ModifierType::SHIFT_MASK) {
        flags |= 1;
    }
    if state.contains(gdk::ModifierType::CONTROL_MASK) {
        flags |= 2;
    }
    if state.contains(gdk::ModifierType::ALT_MASK) {
        flags |= 4;
    }
    flags
}

fn gdk_button_mask_to_buttons(state: gdk::ModifierType) -> i32 {
    let mut buttons = 0;
    if state.contains(gdk::ModifierType::BUTTON1_MASK) {
        buttons |= 1;
    }
    if state.contains(gdk::ModifierType::BUTTON3_MASK) {
        buttons |= 2;
    }
    if state.contains(gdk::ModifierType::BUTTON2_MASK) {
        buttons |= 4;
    }
    buttons
}

fn widget_contains_point(widget: &impl IsA<gtk4::Widget>, x: f64, y: f64) -> bool {
    let widget = widget.as_ref();
    let left = f64::from(widget.margin_start());
    let top = f64::from(widget.margin_top());
    let width = f64::from(widget.width_request().max(0));
    let height = f64::from(widget.height_request().max(0));
    x >= left && x < left + width && y >= top && y < top + height
}
