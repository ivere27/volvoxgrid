use super::{ComposeMethod, ComposeResult};

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct DeadKeyState {
    accent: Option<char>,
}

impl ComposeMethod for DeadKeyState {
    fn should_handle(&self, ch: char) -> bool {
        self.accent.is_some() || is_dead_key(ch)
    }

    fn feed(&mut self, ch: char) -> ComposeResult {
        if let Some(accent) = self.accent.take() {
            if ch == ' ' {
                return ComposeResult::Commit {
                    text: accent.to_string(),
                };
            }
            return ComposeResult::Commit {
                text: compose_dead_key(accent, ch).unwrap_or_else(|| {
                    let mut text = String::new();
                    text.push(accent);
                    text.push(ch);
                    text
                }),
            };
        }

        if !is_dead_key(ch) {
            return ComposeResult::Pass;
        }

        self.accent = Some(ch);
        ComposeResult::Pending {
            preedit: ch.to_string(),
            cursor: 1,
        }
    }

    fn backspace(&mut self) -> ComposeResult {
        if self.accent.take().is_some() {
            return ComposeResult::Pending {
                preedit: String::new(),
                cursor: 0,
            };
        }
        ComposeResult::Pass
    }

    fn reset(&mut self) {
        self.accent = None;
    }

    fn is_active(&self) -> bool {
        self.accent.is_some()
    }
}

fn is_dead_key(ch: char) -> bool {
    matches!(ch, '\'' | '`' | '^' | '~' | '"' | ',' | '/' | ';')
}

fn compose_dead_key(accent: char, ch: char) -> Option<String> {
    let composed = match (accent, ch) {
        ('\'', 'a') => 'á',
        ('\'', 'A') => 'Á',
        ('\'', 'c') => 'ć',
        ('\'', 'C') => 'Ć',
        ('\'', 'e') => 'é',
        ('\'', 'E') => 'É',
        ('\'', 'i') => 'í',
        ('\'', 'I') => 'Í',
        ('\'', 'l') => 'ĺ',
        ('\'', 'L') => 'Ĺ',
        ('\'', 'n') => 'ń',
        ('\'', 'N') => 'Ń',
        ('\'', 'o') => 'ó',
        ('\'', 'O') => 'Ó',
        ('\'', 'r') => 'ŕ',
        ('\'', 'R') => 'Ŕ',
        ('\'', 's') => 'ś',
        ('\'', 'S') => 'Ś',
        ('\'', 'u') => 'ú',
        ('\'', 'U') => 'Ú',
        ('\'', 'y') => 'ý',
        ('\'', 'Y') => 'Ý',
        ('\'', 'z') => 'ź',
        ('\'', 'Z') => 'Ź',
        ('`', 'a') => 'à',
        ('`', 'A') => 'À',
        ('`', 'e') => 'è',
        ('`', 'E') => 'È',
        ('`', 'i') => 'ì',
        ('`', 'I') => 'Ì',
        ('`', 'o') => 'ò',
        ('`', 'O') => 'Ò',
        ('`', 'u') => 'ù',
        ('`', 'U') => 'Ù',
        ('^', 'a') => 'â',
        ('^', 'A') => 'Â',
        ('^', 'c') => 'ĉ',
        ('^', 'C') => 'Ĉ',
        ('^', 'e') => 'ê',
        ('^', 'E') => 'Ê',
        ('^', 'g') => 'ĝ',
        ('^', 'G') => 'Ĝ',
        ('^', 'h') => 'ĥ',
        ('^', 'H') => 'Ĥ',
        ('^', 'i') => 'î',
        ('^', 'I') => 'Î',
        ('^', 'j') => 'ĵ',
        ('^', 'J') => 'Ĵ',
        ('^', 'o') => 'ô',
        ('^', 'O') => 'Ô',
        ('^', 's') => 'ŝ',
        ('^', 'S') => 'Ŝ',
        ('^', 'u') => 'û',
        ('^', 'U') => 'Û',
        ('^', 'w') => 'ŵ',
        ('^', 'W') => 'Ŵ',
        ('^', 'y') => 'ŷ',
        ('^', 'Y') => 'Ŷ',
        ('~', 'a') => 'ã',
        ('~', 'A') => 'Ã',
        ('~', 'i') => 'ĩ',
        ('~', 'I') => 'Ĩ',
        ('~', 'n') => 'ñ',
        ('~', 'N') => 'Ñ',
        ('~', 'o') => 'õ',
        ('~', 'O') => 'Õ',
        ('~', 'u') => 'ũ',
        ('~', 'U') => 'Ũ',
        ('"', 'a') => 'ä',
        ('"', 'A') => 'Ä',
        ('"', 'e') => 'ë',
        ('"', 'E') => 'Ë',
        ('"', 'i') => 'ï',
        ('"', 'I') => 'Ï',
        ('"', 'o') => 'ö',
        ('"', 'O') => 'Ö',
        ('"', 'u') => 'ü',
        ('"', 'U') => 'Ü',
        ('"', 'y') => 'ÿ',
        ('"', 'Y') => 'Ÿ',
        (',', 'c') => 'ç',
        (',', 'C') => 'Ç',
        (',', 's') => 'ş',
        (',', 'S') => 'Ş',
        (',', 't') => 'ţ',
        (',', 'T') => 'Ţ',
        ('/', 'd') => 'đ',
        ('/', 'D') => 'Đ',
        ('/', 'l') => 'ł',
        ('/', 'L') => 'Ł',
        ('/', 'o') => 'ø',
        ('/', 'O') => 'Ø',
        (';', 'c') => 'č',
        (';', 'C') => 'Č',
        (';', 'd') => 'ď',
        (';', 'D') => 'Ď',
        (';', 'e') => 'ě',
        (';', 'E') => 'Ě',
        (';', 'n') => 'ň',
        (';', 'N') => 'Ň',
        (';', 'r') => 'ř',
        (';', 'R') => 'Ř',
        (';', 's') => 'š',
        (';', 'S') => 'Š',
        (';', 't') => 'ť',
        (';', 'T') => 'Ť',
        (';', 'z') => 'ž',
        (';', 'Z') => 'Ž',
        _ => return None,
    };
    Some(composed.to_string())
}

#[cfg(test)]
mod tests {
    use super::DeadKeyState;
    use crate::compose::{ComposeMethod, ComposeResult};

    #[test]
    fn acute_dead_key_composes_latin_letter() {
        let mut state = DeadKeyState::default();
        assert_eq!(
            state.feed('\''),
            ComposeResult::Pending {
                preedit: "'".to_string(),
                cursor: 1
            }
        );
        assert_eq!(
            state.feed('e'),
            ComposeResult::Commit {
                text: "é".to_string()
            }
        );
    }

    #[test]
    fn dead_key_falls_back_to_literal_pair() {
        let mut state = DeadKeyState::default();
        let _ = state.feed('^');
        assert_eq!(
            state.feed('1'),
            ComposeResult::Commit {
                text: "^1".to_string()
            }
        );
    }
}
