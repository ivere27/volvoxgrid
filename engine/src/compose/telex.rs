use super::{ComposeMethod, ComposeResult};

const TONE_NONE: usize = 0;
const TONE_ACUTE: usize = 1;
const TONE_GRAVE: usize = 2;
const TONE_HOOK: usize = 3;
const TONE_TILDE: usize = 4;
const TONE_DOT: usize = 5;

const FORMS_A: [char; 6] = ['a', 'á', 'à', 'ả', 'ã', 'ạ'];
const FORMS_A_BREVE: [char; 6] = ['ă', 'ắ', 'ằ', 'ẳ', 'ẵ', 'ặ'];
const FORMS_A_CIRC: [char; 6] = ['â', 'ấ', 'ầ', 'ẩ', 'ẫ', 'ậ'];
const FORMS_E: [char; 6] = ['e', 'é', 'è', 'ẻ', 'ẽ', 'ẹ'];
const FORMS_E_CIRC: [char; 6] = ['ê', 'ế', 'ề', 'ể', 'ễ', 'ệ'];
const FORMS_I: [char; 6] = ['i', 'í', 'ì', 'ỉ', 'ĩ', 'ị'];
const FORMS_O: [char; 6] = ['o', 'ó', 'ò', 'ỏ', 'õ', 'ọ'];
const FORMS_O_CIRC: [char; 6] = ['ô', 'ố', 'ồ', 'ổ', 'ỗ', 'ộ'];
const FORMS_O_HORN: [char; 6] = ['ơ', 'ớ', 'ờ', 'ở', 'ỡ', 'ợ'];
const FORMS_U: [char; 6] = ['u', 'ú', 'ù', 'ủ', 'ũ', 'ụ'];
const FORMS_U_HORN: [char; 6] = ['ư', 'ứ', 'ừ', 'ử', 'ữ', 'ự'];
const FORMS_Y: [char; 6] = ['y', 'ý', 'ỳ', 'ỷ', 'ỹ', 'ỵ'];

const FORMS_A_UPPER: [char; 6] = ['A', 'Á', 'À', 'Ả', 'Ã', 'Ạ'];
const FORMS_A_BREVE_UPPER: [char; 6] = ['Ă', 'Ắ', 'Ằ', 'Ẳ', 'Ẵ', 'Ặ'];
const FORMS_A_CIRC_UPPER: [char; 6] = ['Â', 'Ấ', 'Ầ', 'Ẩ', 'Ẫ', 'Ậ'];
const FORMS_E_UPPER: [char; 6] = ['E', 'É', 'È', 'Ẻ', 'Ẽ', 'Ẹ'];
const FORMS_E_CIRC_UPPER: [char; 6] = ['Ê', 'Ế', 'Ề', 'Ể', 'Ễ', 'Ệ'];
const FORMS_I_UPPER: [char; 6] = ['I', 'Í', 'Ì', 'Ỉ', 'Ĩ', 'Ị'];
const FORMS_O_UPPER: [char; 6] = ['O', 'Ó', 'Ò', 'Ỏ', 'Õ', 'Ọ'];
const FORMS_O_CIRC_UPPER: [char; 6] = ['Ô', 'Ố', 'Ồ', 'Ổ', 'Ỗ', 'Ộ'];
const FORMS_O_HORN_UPPER: [char; 6] = ['Ơ', 'Ớ', 'Ờ', 'Ở', 'Ỡ', 'Ợ'];
const FORMS_U_UPPER: [char; 6] = ['U', 'Ú', 'Ù', 'Ủ', 'Ũ', 'Ụ'];
const FORMS_U_HORN_UPPER: [char; 6] = ['Ư', 'Ứ', 'Ừ', 'Ử', 'Ữ', 'Ự'];
const FORMS_Y_UPPER: [char; 6] = ['Y', 'Ý', 'Ỳ', 'Ỷ', 'Ỹ', 'Ỵ'];

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct TelexState {
    buffer: String,
    history: Vec<String>,
}

impl ComposeMethod for TelexState {
    fn should_handle(&self, ch: char) -> bool {
        ch.is_ascii_alphabetic()
    }

    fn feed(&mut self, ch: char) -> ComposeResult {
        if !ch.is_ascii_alphabetic() {
            return ComposeResult::Pass;
        }

        let previous = self.buffer.clone();
        let lower = ch.to_ascii_lowercase();
        let handled = match lower {
            's' => apply_tone_key(&mut self.buffer, TONE_ACUTE),
            'f' => apply_tone_key(&mut self.buffer, TONE_GRAVE),
            'r' => apply_tone_key(&mut self.buffer, TONE_HOOK),
            'x' => apply_tone_key(&mut self.buffer, TONE_TILDE),
            'j' => apply_tone_key(&mut self.buffer, TONE_DOT),
            'z' => strip_marks(&mut self.buffer),
            'w' => apply_w_key(&mut self.buffer),
            'a' | 'e' | 'o' => apply_double_vowel(&mut self.buffer, lower),
            'd' => apply_d_key(&mut self.buffer),
            _ => false,
        };

        if !handled {
            self.buffer.push(ch);
        }
        self.history.push(previous);

        ComposeResult::Pending {
            preedit: self.buffer.clone(),
            cursor: self.buffer.chars().count() as i32,
        }
    }

    fn backspace(&mut self) -> ComposeResult {
        if let Some(previous) = self.history.pop() {
            self.buffer = previous;
            return ComposeResult::Pending {
                preedit: self.buffer.clone(),
                cursor: self.buffer.chars().count() as i32,
            };
        }
        ComposeResult::Pass
    }

    fn reset(&mut self) {
        self.buffer.clear();
        self.history.clear();
    }

    fn is_active(&self) -> bool {
        !self.buffer.is_empty()
    }

    fn heap_size_bytes(&self) -> usize {
        let mut bytes = self.buffer.capacity();
        bytes += self.history.capacity() * std::mem::size_of::<String>();
        for item in &self.history {
            bytes += item.capacity();
        }
        bytes
    }
}

fn apply_tone_key(buffer: &mut String, tone: usize) -> bool {
    let mut chars: Vec<char> = buffer.chars().collect();
    let Some(idx) = tone_target_index(&chars) else {
        return false;
    };
    let Some((variant, _, _)) = decompose_vietnamese(chars[idx]) else {
        return false;
    };
    let Some(composed) = compose_vietnamese(variant, tone) else {
        return false;
    };
    chars[idx] = composed;
    *buffer = chars.into_iter().collect();
    true
}

fn apply_w_key(buffer: &mut String) -> bool {
    let mut chars: Vec<char> = buffer.chars().collect();
    let Some(idx) = chars.iter().rposition(|ch| {
        matches!(
            decompose_vietnamese(*ch).map(|(variant, _, _)| lower_variant(variant)),
            Some('a' | 'o' | 'u')
        )
    }) else {
        return false;
    };
    let Some((variant, tone, upper)) = decompose_vietnamese(chars[idx]) else {
        return false;
    };
    let next_variant = match lower_variant(variant) {
        'a' if variant == case_variant('a', upper) => case_variant('ă', upper),
        'o' if variant == case_variant('o', upper) => case_variant('ơ', upper),
        'u' if variant == case_variant('u', upper) => case_variant('ư', upper),
        _ => return false,
    };
    let Some(composed) = compose_vietnamese(next_variant, tone) else {
        return false;
    };
    chars[idx] = composed;
    *buffer = chars.into_iter().collect();
    true
}

fn apply_double_vowel(buffer: &mut String, key: char) -> bool {
    let mut chars: Vec<char> = buffer.chars().collect();
    let Some(idx) = chars.iter().rposition(|ch| {
        matches!(
            decompose_vietnamese(*ch).map(|(variant, _, _)| lower_variant(variant)),
            Some(found) if found == key
        )
    }) else {
        return false;
    };
    let Some((variant, tone, upper)) = decompose_vietnamese(chars[idx]) else {
        return false;
    };
    let plain = case_variant(key, upper);
    if variant != plain {
        return false;
    }
    let next_variant = match key {
        'a' => case_variant('â', upper),
        'e' => case_variant('ê', upper),
        'o' => case_variant('ô', upper),
        _ => return false,
    };
    let Some(composed) = compose_vietnamese(next_variant, tone) else {
        return false;
    };
    chars[idx] = composed;
    *buffer = chars.into_iter().collect();
    true
}

fn apply_d_key(buffer: &mut String) -> bool {
    let mut chars: Vec<char> = buffer.chars().collect();
    let Some(idx) = chars.iter().rposition(|ch| matches!(*ch, 'd' | 'D')) else {
        return false;
    };
    chars[idx] = if chars[idx] == 'D' { 'Đ' } else { 'đ' };
    *buffer = chars.into_iter().collect();
    true
}

fn strip_marks(buffer: &mut String) -> bool {
    let stripped: String = buffer
        .chars()
        .map(|ch| {
            decompose_vietnamese(ch)
                .map(|(variant, _, upper)| case_variant(plain_variant(variant), upper))
                .unwrap_or(ch)
        })
        .collect();
    if stripped == *buffer {
        return false;
    }
    *buffer = stripped;
    true
}

fn tone_target_index(chars: &[char]) -> Option<usize> {
    let vowels: Vec<usize> = chars
        .iter()
        .enumerate()
        .filter_map(|(idx, ch)| {
            decompose_vietnamese(*ch)
                .filter(|(variant, _, _)| is_vowel_variant(*variant))
                .map(|_| idx)
        })
        .collect();
    if vowels.is_empty() {
        return None;
    }

    if let Some(special_idx) = vowels.iter().copied().find(|idx| {
        matches!(
            decompose_vietnamese(chars[*idx]).map(|(variant, _, _)| lower_variant(variant)),
            Some('ă' | 'â' | 'ê' | 'ô' | 'ơ' | 'ư')
        )
    }) {
        return Some(special_idx);
    }

    if vowels.len() >= 3 {
        return Some(vowels[vowels.len() - 2]);
    }

    if vowels.len() == 2 {
        let last = vowels[1];
        let Some((variant, _, _)) = decompose_vietnamese(chars[last]) else {
            return Some(last);
        };
        let ends_with_vowel = chars
            .last()
            .and_then(|ch| decompose_vietnamese(*ch))
            .map(|(variant, _, _)| is_vowel_variant(variant))
            .unwrap_or(false);
        match lower_variant(variant) {
            'y' => return Some(last),
            'i' | 'u' if ends_with_vowel => return Some(vowels[0]),
            _ if ends_with_vowel => return Some(vowels[0]),
            _ => return Some(last),
        }
    }

    Some(vowels[0])
}

fn decompose_vietnamese(ch: char) -> Option<(char, usize, bool)> {
    for (variant, forms) in [
        ('a', &FORMS_A),
        ('ă', &FORMS_A_BREVE),
        ('â', &FORMS_A_CIRC),
        ('e', &FORMS_E),
        ('ê', &FORMS_E_CIRC),
        ('i', &FORMS_I),
        ('o', &FORMS_O),
        ('ô', &FORMS_O_CIRC),
        ('ơ', &FORMS_O_HORN),
        ('u', &FORMS_U),
        ('ư', &FORMS_U_HORN),
        ('y', &FORMS_Y),
    ] {
        if let Some(tone) = forms.iter().position(|candidate| *candidate == ch) {
            return Some((variant, tone, false));
        }
    }
    for (variant, forms) in [
        ('A', &FORMS_A_UPPER),
        ('Ă', &FORMS_A_BREVE_UPPER),
        ('Â', &FORMS_A_CIRC_UPPER),
        ('E', &FORMS_E_UPPER),
        ('Ê', &FORMS_E_CIRC_UPPER),
        ('I', &FORMS_I_UPPER),
        ('O', &FORMS_O_UPPER),
        ('Ô', &FORMS_O_CIRC_UPPER),
        ('Ơ', &FORMS_O_HORN_UPPER),
        ('U', &FORMS_U_UPPER),
        ('Ư', &FORMS_U_HORN_UPPER),
        ('Y', &FORMS_Y_UPPER),
    ] {
        if let Some(tone) = forms.iter().position(|candidate| *candidate == ch) {
            return Some((variant, tone, true));
        }
    }
    match ch {
        'd' => Some(('d', TONE_NONE, false)),
        'đ' => Some(('đ', TONE_NONE, false)),
        'D' => Some(('D', TONE_NONE, true)),
        'Đ' => Some(('Đ', TONE_NONE, true)),
        _ => None,
    }
}

fn compose_vietnamese(variant: char, tone: usize) -> Option<char> {
    if tone > TONE_DOT {
        return None;
    }
    let table: &[char; 6] = match variant {
        'a' => &FORMS_A,
        'ă' => &FORMS_A_BREVE,
        'â' => &FORMS_A_CIRC,
        'e' => &FORMS_E,
        'ê' => &FORMS_E_CIRC,
        'i' => &FORMS_I,
        'o' => &FORMS_O,
        'ô' => &FORMS_O_CIRC,
        'ơ' => &FORMS_O_HORN,
        'u' => &FORMS_U,
        'ư' => &FORMS_U_HORN,
        'y' => &FORMS_Y,
        'A' => &FORMS_A_UPPER,
        'Ă' => &FORMS_A_BREVE_UPPER,
        'Â' => &FORMS_A_CIRC_UPPER,
        'E' => &FORMS_E_UPPER,
        'Ê' => &FORMS_E_CIRC_UPPER,
        'I' => &FORMS_I_UPPER,
        'O' => &FORMS_O_UPPER,
        'Ô' => &FORMS_O_CIRC_UPPER,
        'Ơ' => &FORMS_O_HORN_UPPER,
        'U' => &FORMS_U_UPPER,
        'Ư' => &FORMS_U_HORN_UPPER,
        'Y' => &FORMS_Y_UPPER,
        'd' | 'đ' => return Some(if tone == TONE_NONE { 'đ' } else { 'đ' }),
        'D' | 'Đ' => return Some(if tone == TONE_NONE { 'Đ' } else { 'Đ' }),
        _ => return None,
    };
    Some(table[tone])
}

fn lower_variant(variant: char) -> char {
    match variant {
        'A' => 'a',
        'Ă' => 'ă',
        'Â' => 'â',
        'E' => 'e',
        'Ê' => 'ê',
        'I' => 'i',
        'O' => 'o',
        'Ô' => 'ô',
        'Ơ' => 'ơ',
        'U' => 'u',
        'Ư' => 'ư',
        'Y' => 'y',
        'D' => 'd',
        'Đ' => 'đ',
        _ => variant,
    }
}

fn plain_variant(variant: char) -> char {
    match lower_variant(variant) {
        'ă' | 'â' => 'a',
        'ê' => 'e',
        'ô' | 'ơ' => 'o',
        'ư' => 'u',
        'đ' => 'd',
        other => other,
    }
}

fn case_variant(lower: char, upper: bool) -> char {
    match (lower, upper) {
        ('a', false) => 'a',
        ('a', true) => 'A',
        ('ă', false) => 'ă',
        ('ă', true) => 'Ă',
        ('â', false) => 'â',
        ('â', true) => 'Â',
        ('e', false) => 'e',
        ('e', true) => 'E',
        ('ê', false) => 'ê',
        ('ê', true) => 'Ê',
        ('i', false) => 'i',
        ('i', true) => 'I',
        ('o', false) => 'o',
        ('o', true) => 'O',
        ('ô', false) => 'ô',
        ('ô', true) => 'Ô',
        ('ơ', false) => 'ơ',
        ('ơ', true) => 'Ơ',
        ('u', false) => 'u',
        ('u', true) => 'U',
        ('ư', false) => 'ư',
        ('ư', true) => 'Ư',
        ('y', false) => 'y',
        ('y', true) => 'Y',
        ('d', false) => 'd',
        ('d', true) => 'D',
        ('đ', false) => 'đ',
        ('đ', true) => 'Đ',
        _ => lower,
    }
}

fn is_vowel_variant(variant: char) -> bool {
    matches!(
        lower_variant(variant),
        'a' | 'ă' | 'â' | 'e' | 'ê' | 'i' | 'o' | 'ô' | 'ơ' | 'u' | 'ư' | 'y'
    )
}

#[cfg(test)]
mod tests {
    use super::TelexState;
    use crate::compose::{ComposeMethod, ComposeResult};

    #[test]
    fn telex_double_vowel_builds_circumflex() {
        let mut state = TelexState::default();
        let _ = state.feed('a');
        assert_eq!(
            state.feed('a'),
            ComposeResult::Pending {
                preedit: "â".to_string(),
                cursor: 1
            }
        );
    }

    #[test]
    fn telex_tone_marks_whole_word_buffer() {
        let mut state = TelexState::default();
        let _ = state.feed('b');
        let _ = state.feed('a');
        let _ = state.feed('n');
        assert_eq!(
            state.feed('s'),
            ComposeResult::Pending {
                preedit: "bán".to_string(),
                cursor: 3
            }
        );
    }

    #[test]
    fn telex_backspace_restores_previous_state() {
        let mut state = TelexState::default();
        let _ = state.feed('a');
        let _ = state.feed('w');
        assert_eq!(
            state.backspace(),
            ComposeResult::Pending {
                preedit: "a".to_string(),
                cursor: 1
            }
        );
    }
}
