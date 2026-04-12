use crate::proto::volvoxgrid::v1 as pb;

pub mod deadkey;
pub mod hangul;
pub mod telex;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ComposeResult {
    Pending {
        preedit: String,
        cursor: i32,
    },
    Commit {
        text: String,
    },
    CommitPending {
        commit: String,
        preedit: String,
        cursor: i32,
    },
    Pass,
}

pub trait ComposeMethod {
    fn should_handle(&self, ch: char) -> bool;
    fn feed(&mut self, ch: char) -> ComposeResult;
    fn backspace(&mut self) -> ComposeResult;
    fn reset(&mut self);
    fn is_active(&self) -> bool;
    fn heap_size_bytes(&self) -> usize {
        0
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ActiveCompose {
    None,
    Hangul(hangul::HangulState),
    DeadKey(deadkey::DeadKeyState),
    Telex(telex::TelexState),
}

impl Default for ActiveCompose {
    fn default() -> Self {
        Self::None
    }
}

impl ActiveCompose {
    pub fn for_method(method: i32) -> Self {
        if method == pb::ComposeMethod::Hangul as i32 {
            Self::Hangul(hangul::HangulState::default())
        } else if method == pb::ComposeMethod::DeadKey as i32 {
            Self::DeadKey(deadkey::DeadKeyState::default())
        } else if method == pb::ComposeMethod::Telex as i32 {
            Self::Telex(telex::TelexState::default())
        } else {
            Self::None
        }
    }

    pub fn method(&self) -> i32 {
        match self {
            Self::None => pb::ComposeMethod::None as i32,
            Self::Hangul(_) => pb::ComposeMethod::Hangul as i32,
            Self::DeadKey(_) => pb::ComposeMethod::DeadKey as i32,
            Self::Telex(_) => pb::ComposeMethod::Telex as i32,
        }
    }

    pub fn should_handle(&self, ch: char) -> bool {
        match self {
            Self::None => false,
            Self::Hangul(state) => state.should_handle(ch),
            Self::DeadKey(state) => state.should_handle(ch),
            Self::Telex(state) => state.should_handle(ch),
        }
    }

    pub fn feed(&mut self, ch: char) -> ComposeResult {
        match self {
            Self::None => ComposeResult::Pass,
            Self::Hangul(state) => state.feed(ch),
            Self::DeadKey(state) => state.feed(ch),
            Self::Telex(state) => state.feed(ch),
        }
    }

    pub fn backspace(&mut self) -> ComposeResult {
        match self {
            Self::None => ComposeResult::Pass,
            Self::Hangul(state) => state.backspace(),
            Self::DeadKey(state) => state.backspace(),
            Self::Telex(state) => state.backspace(),
        }
    }

    pub fn reset(&mut self) {
        match self {
            Self::None => {}
            Self::Hangul(state) => state.reset(),
            Self::DeadKey(state) => state.reset(),
            Self::Telex(state) => state.reset(),
        }
    }

    pub fn is_active(&self) -> bool {
        match self {
            Self::None => false,
            Self::Hangul(state) => state.is_active(),
            Self::DeadKey(state) => state.is_active(),
            Self::Telex(state) => state.is_active(),
        }
    }

    pub fn heap_size_bytes(&self) -> usize {
        match self {
            Self::None => 0,
            Self::Hangul(state) => state.heap_size_bytes(),
            Self::DeadKey(state) => state.heap_size_bytes(),
            Self::Telex(state) => state.heap_size_bytes(),
        }
    }
}
