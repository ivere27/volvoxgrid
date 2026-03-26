use std::collections::HashSet;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum LocaleBucket {
    Korean,
    Japanese,
    ChineseSimplified,
    ChineseTraditional,
    Thai,
    Arabic,
    Indic,
    Hebrew,
    Latin,
}

fn locale_bucket(locale: &str) -> LocaleBucket {
    let l = locale.to_ascii_lowercase();
    if l.starts_with("ko") {
        return LocaleBucket::Korean;
    }
    if l.starts_with("ja") {
        return LocaleBucket::Japanese;
    }
    if l.starts_with("zh") {
        if l.contains("hant")
            || l.contains("-tw")
            || l.contains("_tw")
            || l.contains("-hk")
            || l.contains("_hk")
            || l.contains("-mo")
            || l.contains("_mo")
        {
            return LocaleBucket::ChineseTraditional;
        }
        return LocaleBucket::ChineseSimplified;
    }
    if l.starts_with("th") {
        return LocaleBucket::Thai;
    }
    if l.starts_with("ar") {
        return LocaleBucket::Arabic;
    }
    if l.starts_with("he") || l.starts_with("iw") {
        return LocaleBucket::Hebrew;
    }
    if l.starts_with("hi")
        || l.starts_with("mr")
        || l.starts_with("ne")
        || l.starts_with("bn")
        || l.starts_with("ta")
        || l.starts_with("te")
        || l.starts_with("ml")
        || l.starts_with("kn")
        || l.starts_with("gu")
        || l.starts_with("pa")
        || l.starts_with("or")
    {
        return LocaleBucket::Indic;
    }
    LocaleBucket::Latin
}

fn append_unique(
    out: &mut Vec<&'static str>,
    seen: &mut HashSet<&'static str>,
    candidates: &[&'static str],
) {
    for path in candidates {
        if seen.insert(path) {
            out.push(path);
        }
    }
}

#[cfg(target_os = "android")]
const ANDROID_KOREAN_FALLBACKS: &[&str] = &[
    "/system/fonts/NotoSansKR-Regular.otf",
    "/system/fonts/NotoSansKR-VF.ttf",
    "/system/fonts/NanumGothic.ttf",
    "/system/fonts/NanumGothicCoding.ttf",
    "/system/fonts/NotoSansCJKkr-Regular.otf",
    "/system/fonts/NotoSansJP-Regular.otf",
    "/system/fonts/NotoSansSC-Regular.otf",
    "/system/fonts/NotoSansTC-Regular.otf",
    "/system/fonts/NotoSansCJK-Regular.ttc",
    "/system/fonts/NotoSansCJK-VF.ttc",
];
#[cfg(target_os = "android")]
const ANDROID_JAPANESE_FALLBACKS: &[&str] = &[
    "/system/fonts/NotoSansJP-Regular.otf",
    "/system/fonts/NotoSansCJKjp-Regular.otf",
    "/system/fonts/NotoSansCJK-Regular.ttc",
    "/system/fonts/NotoSansKR-Regular.otf",
    "/system/fonts/NotoSansSC-Regular.otf",
    "/system/fonts/NotoSansTC-Regular.otf",
];
#[cfg(target_os = "android")]
const ANDROID_ZH_HANS_FALLBACKS: &[&str] = &[
    "/system/fonts/NotoSansSC-Regular.otf",
    "/system/fonts/NotoSansCJKsc-Regular.otf",
    "/system/fonts/NotoSansCJK-Regular.ttc",
    "/system/fonts/NotoSansTC-Regular.otf",
    "/system/fonts/NotoSansJP-Regular.otf",
    "/system/fonts/NotoSansKR-Regular.otf",
];
#[cfg(target_os = "android")]
const ANDROID_ZH_HANT_FALLBACKS: &[&str] = &[
    "/system/fonts/NotoSansTC-Regular.otf",
    "/system/fonts/NotoSansCJKtc-Regular.otf",
    "/system/fonts/NotoSansCJK-Regular.ttc",
    "/system/fonts/NotoSansSC-Regular.otf",
    "/system/fonts/NotoSansJP-Regular.otf",
    "/system/fonts/NotoSansKR-Regular.otf",
];
#[cfg(target_os = "android")]
const ANDROID_THAI_FALLBACKS: &[&str] = &[
    "/system/fonts/NotoSansThai-Regular.ttf",
    "/system/fonts/NotoSansThaiUI-Regular.ttf",
    "/system/fonts/NotoSansLao-Regular.ttf",
    "/system/fonts/NotoSansKhmer-Regular.ttf",
    "/system/fonts/NotoSansMyanmar-Regular.ttf",
    "/system/fonts/NotoSans-Regular.ttf",
    "/system/fonts/Roboto-Regular.ttf",
    "/system/fonts/NotoSansCJK-Regular.ttc",
    "/system/fonts/NotoSansSC-Regular.otf",
    "/system/fonts/NotoSansTC-Regular.otf",
];
#[cfg(target_os = "android")]
const ANDROID_ARABIC_FALLBACKS: &[&str] = &[
    "/system/fonts/NotoNaskhArabic-Regular.ttf",
    "/system/fonts/NotoSansArabic-Regular.ttf",
    "/system/fonts/NotoSans-Regular.ttf",
];
#[cfg(target_os = "android")]
const ANDROID_INDIC_FALLBACKS: &[&str] = &[
    "/system/fonts/NotoSansDevanagari-Regular.ttf",
    "/system/fonts/NotoSansBengali-Regular.ttf",
    "/system/fonts/NotoSansTamil-Regular.ttf",
    "/system/fonts/NotoSansTelugu-Regular.ttf",
    "/system/fonts/NotoSansMalayalam-Regular.ttf",
    "/system/fonts/NotoSansKannada-Regular.ttf",
    "/system/fonts/NotoSansGujarati-Regular.ttf",
    "/system/fonts/NotoSansGurmukhi-Regular.ttf",
    "/system/fonts/NotoSans-Regular.ttf",
];
#[cfg(target_os = "android")]
const ANDROID_HEBREW_FALLBACKS: &[&str] = &[
    "/system/fonts/NotoSansHebrew-Regular.ttf",
    "/system/fonts/NotoSans-Regular.ttf",
];
#[cfg(target_os = "android")]
const ANDROID_LATIN_FALLBACKS: &[&str] = &[
    "/system/fonts/Roboto-Regular.ttf",
    "/system/fonts/NotoSans-Regular.ttf",
];
#[cfg(target_os = "android")]
const ANDROID_COMMON_FALLBACKS: &[&str] = &[
    "/system/fonts/NotoSans-Regular.ttf",
    "/system/fonts/Roboto-Regular.ttf",
    "/system/fonts/NotoSansCJK-Regular.ttc",
    "/system/fonts/NotoSansCJK-VF.ttc",
    "/system/fonts/DroidSans.ttf",
];

#[cfg(target_os = "linux")]
const LINUX_KOREAN_FALLBACKS: &[&str] = &[
    "/usr/share/fonts/opentype/noto/NotoSansKR-Regular.otf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansJP-Regular.otf",
    "/usr/share/fonts/opentype/noto/NotoSansSC-Regular.otf",
    "/usr/share/fonts/opentype/noto/NotoSansTC-Regular.otf",
];
#[cfg(target_os = "linux")]
const LINUX_JAPANESE_FALLBACKS: &[&str] = &[
    "/usr/share/fonts/opentype/noto/NotoSansJP-Regular.otf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansKR-Regular.otf",
    "/usr/share/fonts/opentype/noto/NotoSansSC-Regular.otf",
];
#[cfg(target_os = "linux")]
const LINUX_ZH_HANS_FALLBACKS: &[&str] = &[
    "/usr/share/fonts/opentype/noto/NotoSansSC-Regular.otf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansTC-Regular.otf",
];
#[cfg(target_os = "linux")]
const LINUX_ZH_HANT_FALLBACKS: &[&str] = &[
    "/usr/share/fonts/opentype/noto/NotoSansTC-Regular.otf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansSC-Regular.otf",
];
#[cfg(target_os = "linux")]
const LINUX_THAI_FALLBACKS: &[&str] = &[
    "/usr/share/fonts/opentype/noto/NotoSansThai-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansLao-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansKhmer-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansMyanmar-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSans-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansSC-Regular.otf",
    "/usr/share/fonts/opentype/noto/NotoSansTC-Regular.otf",
];
#[cfg(target_os = "linux")]
const LINUX_ARABIC_FALLBACKS: &[&str] = &[
    "/usr/share/fonts/opentype/noto/NotoNaskhArabic-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansArabic-Regular.ttf",
];
#[cfg(target_os = "linux")]
const LINUX_INDIC_FALLBACKS: &[&str] = &[
    "/usr/share/fonts/opentype/noto/NotoSansDevanagari-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansBengali-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansTamil-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansTelugu-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansMalayalam-Regular.ttf",
];
#[cfg(target_os = "linux")]
const LINUX_HEBREW_FALLBACKS: &[&str] =
    &["/usr/share/fonts/opentype/noto/NotoSansHebrew-Regular.ttf"];
#[cfg(target_os = "linux")]
const LINUX_LATIN_FALLBACKS: &[&str] = &[
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/opentype/noto/NotoSans-Regular.ttf",
];
#[cfg(target_os = "linux")]
const LINUX_COMMON_FALLBACKS: &[&str] = &[
    // Common Flutter SDK material icon font locations.
    "/snap/flutter/current/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf",
    "/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf",
    "/usr/local/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf",
    "/usr/lib/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf",
    "/usr/share/fonts/opentype/noto/NotoSans-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
];

#[cfg(target_os = "windows")]
const WINDOWS_KOREAN_FALLBACKS: &[&str] = &[
    "C:\\Windows\\Fonts\\malgun.ttf",
    "C:\\Windows\\Fonts\\meiryo.ttc",
    "C:\\Windows\\Fonts\\msyh.ttc",
    "C:\\Windows\\Fonts\\msjh.ttc",
];
#[cfg(target_os = "windows")]
const WINDOWS_JAPANESE_FALLBACKS: &[&str] = &[
    "C:\\Windows\\Fonts\\meiryo.ttc",
    "C:\\Windows\\Fonts\\msgothic.ttc",
    "C:\\Windows\\Fonts\\msyh.ttc",
    "C:\\Windows\\Fonts\\malgun.ttf",
];
#[cfg(target_os = "windows")]
const WINDOWS_ZH_HANS_FALLBACKS: &[&str] = &[
    "C:\\Windows\\Fonts\\msyh.ttc",
    "C:\\Windows\\Fonts\\simsun.ttc",
    "C:\\Windows\\Fonts\\msjh.ttc",
];
#[cfg(target_os = "windows")]
const WINDOWS_ZH_HANT_FALLBACKS: &[&str] = &[
    "C:\\Windows\\Fonts\\msjh.ttc",
    "C:\\Windows\\Fonts\\mingliu.ttc",
    "C:\\Windows\\Fonts\\msyh.ttc",
];
#[cfg(target_os = "windows")]
const WINDOWS_THAI_FALLBACKS: &[&str] = &[
    "C:\\Windows\\Fonts\\leelawui.ttf",
    "C:\\Windows\\Fonts\\tahoma.ttf",
    "C:\\Windows\\Fonts\\segoeui.ttf",
    "C:\\Windows\\Fonts\\msyh.ttc",
    "C:\\Windows\\Fonts\\msjh.ttc",
];
#[cfg(target_os = "windows")]
const WINDOWS_ARABIC_FALLBACKS: &[&str] = &[
    "C:\\Windows\\Fonts\\segoeui.ttf",
    "C:\\Windows\\Fonts\\arial.ttf",
    "C:\\Windows\\Fonts\\trado.ttf",
];
#[cfg(target_os = "windows")]
const WINDOWS_INDIC_FALLBACKS: &[&str] = &[
    "C:\\Windows\\Fonts\\nirmala.ttf",
    "C:\\Windows\\Fonts\\mangal.ttf",
    "C:\\Windows\\Fonts\\kokila.ttf",
];
#[cfg(target_os = "windows")]
const WINDOWS_HEBREW_FALLBACKS: &[&str] = &[
    "C:\\Windows\\Fonts\\arial.ttf",
    "C:\\Windows\\Fonts\\segoeui.ttf",
];
#[cfg(target_os = "windows")]
const WINDOWS_LATIN_FALLBACKS: &[&str] = &[
    "C:\\Windows\\Fonts\\segoeui.ttf",
    "C:\\Windows\\Fonts\\arial.ttf",
];
#[cfg(target_os = "windows")]
const WINDOWS_COMMON_FALLBACKS: &[&str] = &[
    "C:\\Windows\\Fonts\\segoeui.ttf",
    "C:\\Windows\\Fonts\\arial.ttf",
    "C:\\Windows\\Fonts\\seguiemj.ttf",
    // CJK fallback — Microsoft YaHei covers CJK Unified Ideographs, Hangul,
    // and Kana so that CJK text renders even when the locale is Latin.
    "C:\\Windows\\Fonts\\msyh.ttc",
    "C:\\Windows\\Fonts\\msjh.ttc",
    "C:\\Windows\\Fonts\\malgun.ttf",
];

#[cfg(any(target_os = "macos", target_os = "ios"))]
const APPLE_KOREAN_FALLBACKS: &[&str] = &[
    "/System/Library/Fonts/AppleSDGothicNeo.ttc",
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
];
#[cfg(any(target_os = "macos", target_os = "ios"))]
const APPLE_JAPANESE_FALLBACKS: &[&str] = &[
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/PingFang.ttc",
];
#[cfg(any(target_os = "macos", target_os = "ios"))]
const APPLE_CHINESE_FALLBACKS: &[&str] = &[
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
];
#[cfg(any(target_os = "macos", target_os = "ios"))]
const APPLE_THAI_FALLBACKS: &[&str] = &[
    "/System/Library/Fonts/Thonburi.ttc",
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
];
#[cfg(any(target_os = "macos", target_os = "ios"))]
const APPLE_ARABIC_FALLBACKS: &[&str] = &["/System/Library/Fonts/GeezaPro.ttc"];
#[cfg(any(target_os = "macos", target_os = "ios"))]
const APPLE_INDIC_FALLBACKS: &[&str] = &["/System/Library/Fonts/KohinoorDevanagari.ttc"];
#[cfg(any(target_os = "macos", target_os = "ios"))]
const APPLE_HEBREW_FALLBACKS: &[&str] = &["/System/Library/Fonts/Supplemental/Arial Hebrew.ttf"];
#[cfg(any(target_os = "macos", target_os = "ios"))]
const APPLE_LATIN_FALLBACKS: &[&str] = &[
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Helvetica.ttc",
];
#[cfg(any(target_os = "macos", target_os = "ios"))]
const APPLE_COMMON_FALLBACKS: &[&str] = &[
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Helvetica.ttc",
    "/System/Library/Fonts/PingFang.ttc",
];

#[cfg(not(target_arch = "wasm32"))]
fn locale_candidates_for_bucket(bucket: LocaleBucket) -> &'static [&'static str] {
    #[cfg(target_os = "android")]
    {
        return match bucket {
            LocaleBucket::Korean => ANDROID_KOREAN_FALLBACKS,
            LocaleBucket::Japanese => ANDROID_JAPANESE_FALLBACKS,
            LocaleBucket::ChineseSimplified => ANDROID_ZH_HANS_FALLBACKS,
            LocaleBucket::ChineseTraditional => ANDROID_ZH_HANT_FALLBACKS,
            LocaleBucket::Thai => ANDROID_THAI_FALLBACKS,
            LocaleBucket::Arabic => ANDROID_ARABIC_FALLBACKS,
            LocaleBucket::Indic => ANDROID_INDIC_FALLBACKS,
            LocaleBucket::Hebrew => ANDROID_HEBREW_FALLBACKS,
            LocaleBucket::Latin => ANDROID_LATIN_FALLBACKS,
        };
    }

    #[cfg(target_os = "linux")]
    {
        return match bucket {
            LocaleBucket::Korean => LINUX_KOREAN_FALLBACKS,
            LocaleBucket::Japanese => LINUX_JAPANESE_FALLBACKS,
            LocaleBucket::ChineseSimplified => LINUX_ZH_HANS_FALLBACKS,
            LocaleBucket::ChineseTraditional => LINUX_ZH_HANT_FALLBACKS,
            LocaleBucket::Thai => LINUX_THAI_FALLBACKS,
            LocaleBucket::Arabic => LINUX_ARABIC_FALLBACKS,
            LocaleBucket::Indic => LINUX_INDIC_FALLBACKS,
            LocaleBucket::Hebrew => LINUX_HEBREW_FALLBACKS,
            LocaleBucket::Latin => LINUX_LATIN_FALLBACKS,
        };
    }

    #[cfg(target_os = "windows")]
    {
        return match bucket {
            LocaleBucket::Korean => WINDOWS_KOREAN_FALLBACKS,
            LocaleBucket::Japanese => WINDOWS_JAPANESE_FALLBACKS,
            LocaleBucket::ChineseSimplified => WINDOWS_ZH_HANS_FALLBACKS,
            LocaleBucket::ChineseTraditional => WINDOWS_ZH_HANT_FALLBACKS,
            LocaleBucket::Thai => WINDOWS_THAI_FALLBACKS,
            LocaleBucket::Arabic => WINDOWS_ARABIC_FALLBACKS,
            LocaleBucket::Indic => WINDOWS_INDIC_FALLBACKS,
            LocaleBucket::Hebrew => WINDOWS_HEBREW_FALLBACKS,
            LocaleBucket::Latin => WINDOWS_LATIN_FALLBACKS,
        };
    }

    #[cfg(any(target_os = "macos", target_os = "ios"))]
    {
        return match bucket {
            LocaleBucket::Korean => APPLE_KOREAN_FALLBACKS,
            LocaleBucket::Japanese => APPLE_JAPANESE_FALLBACKS,
            LocaleBucket::ChineseSimplified | LocaleBucket::ChineseTraditional => {
                APPLE_CHINESE_FALLBACKS
            }
            LocaleBucket::Thai => APPLE_THAI_FALLBACKS,
            LocaleBucket::Arabic => APPLE_ARABIC_FALLBACKS,
            LocaleBucket::Indic => APPLE_INDIC_FALLBACKS,
            LocaleBucket::Hebrew => APPLE_HEBREW_FALLBACKS,
            LocaleBucket::Latin => APPLE_LATIN_FALLBACKS,
        };
    }

    #[cfg(not(any(
        target_os = "android",
        target_os = "linux",
        target_os = "windows",
        target_os = "macos",
        target_os = "ios"
    )))]
    {
        let _ = bucket;
        &[]
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn common_candidates_for_platform() -> &'static [&'static str] {
    #[cfg(target_os = "android")]
    {
        return ANDROID_COMMON_FALLBACKS;
    }

    #[cfg(target_os = "linux")]
    {
        return LINUX_COMMON_FALLBACKS;
    }

    #[cfg(target_os = "windows")]
    {
        return WINDOWS_COMMON_FALLBACKS;
    }

    #[cfg(any(target_os = "macos", target_os = "ios"))]
    {
        return APPLE_COMMON_FALLBACKS;
    }

    #[cfg(not(any(
        target_os = "android",
        target_os = "linux",
        target_os = "windows",
        target_os = "macos",
        target_os = "ios"
    )))]
    {
        &[]
    }
}

#[cfg(not(target_arch = "wasm32"))]
pub(crate) fn platform_fallback_candidates(locale_hint: &str) -> Vec<&'static str> {
    let mut candidates = Vec::new();
    let mut seen = HashSet::new();
    let bucket = locale_bucket(locale_hint);
    append_unique(
        &mut candidates,
        &mut seen,
        locale_candidates_for_bucket(bucket),
    );
    append_unique(&mut candidates, &mut seen, common_candidates_for_platform());
    candidates
}

#[cfg(target_arch = "wasm32")]
pub(crate) fn platform_fallback_candidates(_locale_hint: &str) -> Vec<&'static str> {
    Vec::new()
}
