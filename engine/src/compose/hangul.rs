use super::{ComposeMethod, ComposeResult};

const CHOSEONG_COMPAT: [char; 19] = [
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ',
    'ㅌ', 'ㅍ', 'ㅎ',
];

const JUNGSEONG_COMPAT: [char; 21] = [
    'ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ', 'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ',
    'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ',
];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct ConsonantKey {
    choseong: u8,
    jongseong: Option<u8>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum JamoKey {
    Consonant(ConsonantKey),
    Vowel(u8),
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct HangulState {
    initial: Option<u8>,
    medial: Option<u8>,
    final_consonant: Option<u8>,
}

impl ComposeMethod for HangulState {
    fn should_handle(&self, ch: char) -> bool {
        map_key(ch).is_some()
    }

    fn feed(&mut self, ch: char) -> ComposeResult {
        let Some(key) = map_key(ch) else {
            return ComposeResult::Pass;
        };

        match (self.initial, self.medial, self.final_consonant) {
            (None, None, None) => {
                self.apply_empty(key);
                pending_result(self.render())
            }
            (Some(_), None, None) => self.feed_after_initial_only(key),
            (None, Some(_), None) => self.feed_after_vowel_only(key),
            (Some(_), Some(_), None) => self.feed_after_lv(key),
            (Some(_), Some(_), Some(_)) => self.feed_after_lvt(key),
            _ => {
                self.reset();
                ComposeResult::Pass
            }
        }
    }

    fn backspace(&mut self) -> ComposeResult {
        if let Some(final_consonant) = self.final_consonant {
            self.final_consonant = split_final(final_consonant).map(|(left, _)| left);
            return pending_result(self.render());
        }

        if let Some(medial) = self.medial {
            self.medial = split_medial(medial).map(|(left, _)| left);
            return pending_result(self.render());
        }

        if self.initial.take().is_some() {
            return pending_result(self.render());
        }

        ComposeResult::Pass
    }

    fn reset(&mut self) {
        self.initial = None;
        self.medial = None;
        self.final_consonant = None;
    }

    fn is_active(&self) -> bool {
        self.initial.is_some() || self.medial.is_some() || self.final_consonant.is_some()
    }
}

impl HangulState {
    fn render(&self) -> String {
        if let Some(initial) = self.initial {
            if let Some(medial) = self.medial {
                return compose_syllable(initial, medial, self.final_consonant.unwrap_or(0))
                    .to_string();
            }
            return CHOSEONG_COMPAT[initial as usize].to_string();
        }

        if let Some(medial) = self.medial {
            return JUNGSEONG_COMPAT[medial as usize].to_string();
        }

        String::new()
    }

    fn apply_empty(&mut self, key: JamoKey) {
        match key {
            JamoKey::Consonant(consonant) => {
                self.initial = Some(consonant.choseong);
                self.medial = None;
                self.final_consonant = None;
            }
            JamoKey::Vowel(medial) => {
                self.initial = None;
                self.medial = Some(medial);
                self.final_consonant = None;
            }
        }
    }

    fn feed_after_initial_only(&mut self, key: JamoKey) -> ComposeResult {
        match key {
            JamoKey::Vowel(medial) => {
                self.medial = Some(medial);
                pending_result(self.render())
            }
            JamoKey::Consonant(consonant) => {
                let commit = self.render();
                self.initial = Some(consonant.choseong);
                self.medial = None;
                self.final_consonant = None;
                commit_pending_result(commit, self.render())
            }
        }
    }

    fn feed_after_vowel_only(&mut self, key: JamoKey) -> ComposeResult {
        match key {
            JamoKey::Vowel(medial) => {
                if let Some(current) = self.medial {
                    if let Some(compound) = combine_medial(current, medial) {
                        self.medial = Some(compound);
                        return pending_result(self.render());
                    }
                }
                let commit = self.render();
                self.initial = None;
                self.medial = Some(medial);
                self.final_consonant = None;
                commit_pending_result(commit, self.render())
            }
            JamoKey::Consonant(consonant) => {
                let commit = self.render();
                self.initial = Some(consonant.choseong);
                self.medial = None;
                self.final_consonant = None;
                commit_pending_result(commit, self.render())
            }
        }
    }

    fn feed_after_lv(&mut self, key: JamoKey) -> ComposeResult {
        match key {
            JamoKey::Vowel(medial) => {
                if let Some(current) = self.medial {
                    if let Some(compound) = combine_medial(current, medial) {
                        self.medial = Some(compound);
                        return pending_result(self.render());
                    }
                }
                let commit = self.render();
                self.initial = None;
                self.medial = Some(medial);
                self.final_consonant = None;
                commit_pending_result(commit, self.render())
            }
            JamoKey::Consonant(consonant) => {
                if let Some(jongseong) = consonant.jongseong {
                    self.final_consonant = Some(jongseong);
                    return pending_result(self.render());
                }
                let commit = self.render();
                self.initial = Some(consonant.choseong);
                self.medial = None;
                self.final_consonant = None;
                commit_pending_result(commit, self.render())
            }
        }
    }

    fn feed_after_lvt(&mut self, key: JamoKey) -> ComposeResult {
        match key {
            JamoKey::Consonant(consonant) => {
                if let (Some(final_consonant), Some(jongseong)) =
                    (self.final_consonant, consonant.jongseong)
                {
                    if let Some(compound) = combine_final(final_consonant, jongseong) {
                        self.final_consonant = Some(compound);
                        return pending_result(self.render());
                    }
                }

                let commit = self.render();
                self.initial = Some(consonant.choseong);
                self.medial = None;
                self.final_consonant = None;
                commit_pending_result(commit, self.render())
            }
            JamoKey::Vowel(medial) => {
                let Some(initial) = self.initial else {
                    return ComposeResult::Pass;
                };
                let Some(current_medial) = self.medial else {
                    return ComposeResult::Pass;
                };
                let Some(final_consonant) = self.final_consonant else {
                    return ComposeResult::Pass;
                };

                let (left_final, next_initial) =
                    if let Some((left, right)) = split_final(final_consonant) {
                        let Some(next_initial) = final_to_initial(right) else {
                            let commit = self.render();
                            self.initial = None;
                            self.medial = Some(medial);
                            self.final_consonant = None;
                            return commit_pending_result(commit, self.render());
                        };
                        (Some(left), next_initial)
                    } else {
                        let Some(next_initial) = final_to_initial(final_consonant) else {
                            let commit = self.render();
                            self.initial = None;
                            self.medial = Some(medial);
                            self.final_consonant = None;
                            return commit_pending_result(commit, self.render());
                        };
                        (None, next_initial)
                    };

                let commit =
                    compose_syllable(initial, current_medial, left_final.unwrap_or(0)).to_string();
                self.initial = Some(next_initial);
                self.medial = Some(medial);
                self.final_consonant = None;
                commit_pending_result(commit, self.render())
            }
        }
    }
}

fn pending_result(preedit: String) -> ComposeResult {
    ComposeResult::Pending {
        cursor: preedit.chars().count() as i32,
        preedit,
    }
}

fn commit_pending_result(commit: String, preedit: String) -> ComposeResult {
    ComposeResult::CommitPending {
        commit,
        cursor: preedit.chars().count() as i32,
        preedit,
    }
}

fn compose_syllable(initial: u8, medial: u8, final_consonant: u8) -> char {
    let scalar = 0xAC00 + (((initial as u32) * 21 + medial as u32) * 28) + final_consonant as u32;
    char::from_u32(scalar).unwrap_or('\u{FFFD}')
}

fn map_key(ch: char) -> Option<JamoKey> {
    use JamoKey::{Consonant, Vowel};

    let consonant = |choseong, jongseong| {
        Consonant(ConsonantKey {
            choseong,
            jongseong,
        })
    };

    Some(match ch {
        'r' => consonant(0, Some(1)),
        'R' => consonant(1, Some(2)),
        's' => consonant(2, Some(4)),
        'e' => consonant(3, Some(7)),
        'E' => consonant(4, None),
        'f' => consonant(5, Some(8)),
        'a' => consonant(6, Some(16)),
        'q' => consonant(7, Some(17)),
        'Q' => consonant(8, None),
        't' => consonant(9, Some(19)),
        'T' => consonant(10, Some(20)),
        'd' => consonant(11, Some(21)),
        'w' => consonant(12, Some(22)),
        'W' => consonant(13, None),
        'c' => consonant(14, Some(23)),
        'z' => consonant(15, Some(24)),
        'x' => consonant(16, Some(25)),
        'v' => consonant(17, Some(26)),
        'g' => consonant(18, Some(27)),
        'k' => Vowel(0),
        'o' => Vowel(1),
        'i' => Vowel(2),
        'O' => Vowel(3),
        'j' => Vowel(4),
        'p' => Vowel(5),
        'u' => Vowel(6),
        'P' => Vowel(7),
        'h' => Vowel(8),
        'y' => Vowel(12),
        'n' => Vowel(13),
        'b' => Vowel(17),
        'm' => Vowel(18),
        'l' => Vowel(20),
        _ => return None,
    })
}

fn combine_medial(left: u8, right: u8) -> Option<u8> {
    match (left, right) {
        (8, 0) => Some(9),
        (8, 1) => Some(10),
        (8, 20) => Some(11),
        (13, 4) => Some(14),
        (13, 5) => Some(15),
        (13, 20) => Some(16),
        (18, 20) => Some(19),
        _ => None,
    }
}

fn split_medial(compound: u8) -> Option<(u8, u8)> {
    match compound {
        9 => Some((8, 0)),
        10 => Some((8, 1)),
        11 => Some((8, 20)),
        14 => Some((13, 4)),
        15 => Some((13, 5)),
        16 => Some((13, 20)),
        19 => Some((18, 20)),
        _ => None,
    }
}

fn combine_final(left: u8, right: u8) -> Option<u8> {
    match (left, right) {
        (1, 19) => Some(3),
        (4, 22) => Some(5),
        (4, 27) => Some(6),
        (8, 1) => Some(9),
        (8, 16) => Some(10),
        (8, 17) => Some(11),
        (8, 19) => Some(12),
        (8, 25) => Some(13),
        (8, 26) => Some(14),
        (8, 27) => Some(15),
        (17, 19) => Some(18),
        _ => None,
    }
}

fn split_final(compound: u8) -> Option<(u8, u8)> {
    match compound {
        3 => Some((1, 19)),
        5 => Some((4, 22)),
        6 => Some((4, 27)),
        9 => Some((8, 1)),
        10 => Some((8, 16)),
        11 => Some((8, 17)),
        12 => Some((8, 19)),
        13 => Some((8, 25)),
        14 => Some((8, 26)),
        15 => Some((8, 27)),
        18 => Some((17, 19)),
        _ => None,
    }
}

fn final_to_initial(final_consonant: u8) -> Option<u8> {
    match final_consonant {
        1 => Some(0),
        2 => Some(1),
        4 => Some(2),
        7 => Some(3),
        8 => Some(5),
        16 => Some(6),
        17 => Some(7),
        19 => Some(9),
        20 => Some(10),
        21 => Some(11),
        22 => Some(12),
        23 => Some(14),
        24 => Some(15),
        25 => Some(16),
        26 => Some(17),
        27 => Some(18),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::HangulState;
    use crate::compose::{ComposeMethod, ComposeResult};

    #[test]
    fn composes_basic_syllable() {
        let mut state = HangulState::default();
        assert_eq!(
            state.feed('r'),
            ComposeResult::Pending {
                preedit: "ㄱ".to_string(),
                cursor: 1
            }
        );
        assert_eq!(
            state.feed('k'),
            ComposeResult::Pending {
                preedit: "가".to_string(),
                cursor: 1
            }
        );
    }

    #[test]
    fn moves_final_to_next_syllable_on_vowel() {
        let mut state = HangulState::default();
        let _ = state.feed('r');
        let _ = state.feed('k');
        let _ = state.feed('s');
        assert_eq!(
            state.feed('k'),
            ComposeResult::CommitPending {
                commit: "가".to_string(),
                preedit: "나".to_string(),
                cursor: 1
            }
        );
    }

    #[test]
    fn backspace_unwinds_jamo() {
        let mut state = HangulState::default();
        let _ = state.feed('r');
        let _ = state.feed('k');
        let _ = state.feed('s');
        assert_eq!(
            state.backspace(),
            ComposeResult::Pending {
                preedit: "가".to_string(),
                cursor: 1
            }
        );
        assert_eq!(
            state.backspace(),
            ComposeResult::Pending {
                preedit: "ㄱ".to_string(),
                cursor: 1
            }
        );
    }
}
