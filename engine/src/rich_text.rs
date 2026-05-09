use crate::proto::volvoxgrid::v1 as pb;

pub fn utf16_len(text: &str) -> u32 {
    text.encode_utf16().count().min(u32::MAX as usize) as u32
}

pub fn utf16_index_to_byte_index(text: &str, index: u32) -> Option<usize> {
    let target = index as usize;
    if target == 0 {
        return Some(0);
    }

    let mut units = 0usize;
    for (byte_index, ch) in text.char_indices() {
        if units == target {
            return Some(byte_index);
        }
        let next = units + ch.len_utf16();
        if target > units && target < next {
            return None;
        }
        units = next;
    }

    (units == target).then_some(text.len())
}

pub fn validate_rich_text(text: &str, rich_text: &pb::RichText) -> Result<(), String> {
    let text_len = utf16_len(text);
    let mut previous = None;

    for run in &rich_text.runs {
        if run.start_index > text_len {
            return Err(format!(
                "Rich text run start_index {} exceeds UTF-16 text length {}",
                run.start_index, text_len
            ));
        }
        if let Some(prev) = previous {
            if run.start_index <= prev {
                return Err("Rich text run start_index values must be strictly increasing".into());
            }
        }
        if utf16_index_to_byte_index(text, run.start_index).is_none() {
            return Err(format!(
                "Rich text run start_index {} splits a UTF-16 surrogate pair",
                run.start_index
            ));
        }
        previous = Some(run.start_index);
    }

    Ok(())
}

pub fn rich_text_heap_size_bytes(rich_text: &pb::RichText) -> usize {
    let mut bytes = rich_text.runs.capacity() * std::mem::size_of::<pb::TextFormatRun>();
    for run in &rich_text.runs {
        if let Some(style) = &run.style {
            bytes += style.link_url.as_ref().map_or(0, String::capacity);
            if let Some(font) = &style.font {
                bytes += font.family.as_ref().map_or(0, String::capacity);
                bytes += font.families.capacity() * std::mem::size_of::<String>();
                for family in &font.families {
                    bytes += family.capacity();
                }
            }
        }
    }
    bytes
}

#[cfg(test)]
mod tests {
    use super::*;

    fn run(start_index: u32) -> pb::TextFormatRun {
        pb::TextFormatRun {
            start_index,
            style: Some(pb::TextRunStyle::default()),
        }
    }

    #[test]
    fn utf16_index_conversion_rejects_surrogate_split() {
        assert_eq!(utf16_len("a😀b"), 4);
        assert_eq!(utf16_index_to_byte_index("a😀b", 0), Some(0));
        assert_eq!(utf16_index_to_byte_index("a😀b", 1), Some(1));
        assert_eq!(utf16_index_to_byte_index("a😀b", 2), None);
        assert_eq!(utf16_index_to_byte_index("a😀b", 3), Some(5));
        assert_eq!(utf16_index_to_byte_index("a😀b", 4), Some(6));
    }

    #[test]
    fn rich_text_validation_rejects_unsorted_duplicate_and_out_of_range_runs() {
        assert!(validate_rich_text(
            "abcd",
            &pb::RichText {
                runs: vec![run(0), run(2)]
            }
        )
        .is_ok());
        assert!(validate_rich_text(
            "abcd",
            &pb::RichText {
                runs: vec![run(2), run(1)]
            }
        )
        .is_err());
        assert!(validate_rich_text(
            "abcd",
            &pb::RichText {
                runs: vec![run(1), run(1)]
            }
        )
        .is_err());
        assert!(validate_rich_text("abcd", &pb::RichText { runs: vec![run(5)] }).is_err());
    }
}
