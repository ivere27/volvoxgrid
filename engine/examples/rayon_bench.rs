#[cfg(not(feature = "demo"))]
fn main() {
    eprintln!("rayon_bench requires the `demo` feature");
    std::process::exit(1);
}

#[cfg(feature = "demo")]
mod app {
    use std::env;
    use std::hint::black_box;
    use std::time::Instant;

    use volvoxgrid_engine::demo::{self, STRESS_DATA_ROWS};
    use volvoxgrid_engine::grid::VolvoxGrid;
    use volvoxgrid_engine::sort::{
        sort_grid_all, sort_grid_all_multi, SORT_ASCENDING_NUMERIC, SORT_ASCENDING_STRING,
    };

    const DEFAULT_SMALL_ROWS: i32 = 50_000;
    const DEFAULT_MEDIUM_ROWS: i32 = 250_000;
    const DEFAULT_SMALL_ROUNDS: usize = 5;
    const DEFAULT_MEDIUM_ROUNDS: usize = 3;
    const DEFAULT_STRESS_ROUNDS: usize = 1;

    #[derive(Clone, Copy)]
    struct Config {
        small_rows: i32,
        medium_rows: i32,
        small_rounds: usize,
        medium_rounds: usize,
        stress_rounds: usize,
    }

    impl Default for Config {
        fn default() -> Self {
            Self {
                small_rows: DEFAULT_SMALL_ROWS,
                medium_rows: DEFAULT_MEDIUM_ROWS,
                small_rounds: DEFAULT_SMALL_ROUNDS,
                medium_rounds: DEFAULT_MEDIUM_ROUNDS,
                stress_rounds: DEFAULT_STRESS_ROUNDS,
            }
        }
    }

    #[derive(Clone)]
    struct CaseResult {
        name: String,
        samples_ms: Vec<f64>,
        digest: u64,
    }

    pub fn run() {
        let config = parse_args();
        let thread_count = std::thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(1);

        println!(
            "rayon_bench feature_rayon={} threads={} release_profile=release",
            cfg!(feature = "rayon"),
            thread_count
        );
        println!(
            "config small_rows={} medium_rows={} small_rounds={} medium_rounds={} stress_rounds={}",
            config.small_rows,
            config.medium_rows,
            config.small_rounds,
            config.medium_rounds,
            config.stress_rounds
        );

        let results = vec![
            bench_sort_case(
                "synthetic_numeric_sort_small",
                config.small_rounds,
                || make_synthetic_grid(config.small_rows),
                |grid| sort_grid_all(grid, SORT_ASCENDING_NUMERIC, 1),
                &[(1, 1), (config.small_rows / 2, 1), (config.small_rows, 1)],
            ),
            bench_sort_case(
                "synthetic_numeric_sort_medium",
                config.medium_rounds,
                || make_synthetic_grid(config.medium_rows),
                |grid| sort_grid_all(grid, SORT_ASCENDING_NUMERIC, 1),
                &[(1, 1), (config.medium_rows / 2, 1), (config.medium_rows, 1)],
            ),
            bench_sort_case(
                "synthetic_multikey_sort_medium",
                config.medium_rounds,
                || make_synthetic_grid(config.medium_rows),
                |grid| {
                    grid.sort_state.sort_keys = vec![
                        (0, SORT_ASCENDING_STRING),
                        (1, SORT_ASCENDING_NUMERIC),
                        (2, SORT_ASCENDING_STRING),
                    ];
                    sort_grid_all_multi(grid);
                },
                &[
                    (1, 0),
                    (1, 1),
                    (config.medium_rows / 2, 0),
                    (config.medium_rows, 2),
                ],
            ),
            bench_setup_case("stress_setup_1m", config.stress_rounds),
            bench_sort_case(
                "stress_numeric_sort_1m",
                config.stress_rounds,
                || {
                    let mut grid = VolvoxGrid::new(7, 1280, 900, 1, 1, 0, 1);
                    demo::setup_stress_demo(&mut grid);
                    grid
                },
                |grid| sort_grid_all(grid, SORT_ASCENDING_NUMERIC, 1),
                &[(0, 1), (STRESS_DATA_ROWS / 2, 1), (STRESS_DATA_ROWS - 1, 1)],
            ),
            bench_sort_case(
                "stress_string_sort_1m",
                config.stress_rounds,
                || {
                    let mut grid = VolvoxGrid::new(8, 1280, 900, 1, 1, 0, 1);
                    demo::setup_stress_demo(&mut grid);
                    grid
                },
                |grid| sort_grid_all(grid, SORT_ASCENDING_STRING, 10),
                &[
                    (0, 10),
                    (STRESS_DATA_ROWS / 2, 10),
                    (STRESS_DATA_ROWS - 1, 10),
                ],
            ),
        ];

        println!();
        println!("summary");
        for result in &results {
            print_case_summary(result);
        }
    }

    fn parse_args() -> Config {
        let mut config = Config::default();
        let mut args = env::args().skip(1);
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--small-rows" => config.small_rows = parse_i32_arg(arg.as_str(), args.next()),
                "--medium-rows" => config.medium_rows = parse_i32_arg(arg.as_str(), args.next()),
                "--small-rounds" => {
                    config.small_rounds = parse_usize_arg(arg.as_str(), args.next())
                }
                "--medium-rounds" => {
                    config.medium_rounds = parse_usize_arg(arg.as_str(), args.next())
                }
                "--stress-rounds" => {
                    config.stress_rounds = parse_usize_arg(arg.as_str(), args.next())
                }
                "--help" | "-h" => {
                    print_help();
                    std::process::exit(0);
                }
                _ => {
                    eprintln!("unknown argument: {arg}");
                    print_help();
                    std::process::exit(2);
                }
            }
        }
        config.small_rows = config.small_rows.max(2);
        config.medium_rows = config.medium_rows.max(config.small_rows);
        config.small_rounds = config.small_rounds.max(1);
        config.medium_rounds = config.medium_rounds.max(1);
        config.stress_rounds = config.stress_rounds.max(1);
        config
    }

    fn parse_i32_arg(flag: &str, value: Option<String>) -> i32 {
        value
            .unwrap_or_else(|| {
                eprintln!("missing value for {flag}");
                std::process::exit(2);
            })
            .parse::<i32>()
            .unwrap_or_else(|err| {
                eprintln!("invalid integer for {flag}: {err}");
                std::process::exit(2);
            })
    }

    fn parse_usize_arg(flag: &str, value: Option<String>) -> usize {
        value
            .unwrap_or_else(|| {
                eprintln!("missing value for {flag}");
                std::process::exit(2);
            })
            .parse::<usize>()
            .unwrap_or_else(|err| {
                eprintln!("invalid integer for {flag}: {err}");
                std::process::exit(2);
            })
    }

    fn print_help() {
        println!("rayon_bench options:");
        println!("  --small-rows <n>");
        println!("  --medium-rows <n>");
        println!("  --small-rounds <n>");
        println!("  --medium-rounds <n>");
        println!("  --stress-rounds <n>");
    }

    fn bench_setup_case(name: &str, rounds: usize) -> CaseResult {
        let mut samples_ms = Vec::with_capacity(rounds);
        let mut digest = 0u64;
        for _ in 0..rounds {
            let mut grid = VolvoxGrid::new(42, 1280, 900, 1, 1, 0, 1);
            let started = Instant::now();
            demo::setup_stress_demo(&mut grid);
            let elapsed_ms = started.elapsed().as_secs_f64() * 1000.0;
            samples_ms.push(elapsed_ms);
            digest ^= grid_digest(
                &grid,
                &[
                    (0, 0),
                    (0, 10),
                    (STRESS_DATA_ROWS / 2, 7),
                    (STRESS_DATA_ROWS - 1, 10),
                ],
            );
            black_box(grid.sort_state.last_sort_elapsed_ms);
        }
        CaseResult {
            name: name.to_string(),
            samples_ms,
            digest,
        }
    }

    fn bench_sort_case<G, B>(
        name: &str,
        rounds: usize,
        mut build_grid: G,
        mut bench: B,
        digest_points: &[(i32, i32)],
    ) -> CaseResult
    where
        G: FnMut() -> VolvoxGrid,
        B: FnMut(&mut VolvoxGrid),
    {
        let mut samples_ms = Vec::with_capacity(rounds);
        let mut digest = 0u64;
        for _ in 0..rounds {
            let mut grid = build_grid();
            let started = Instant::now();
            bench(&mut grid);
            let elapsed_ms = started.elapsed().as_secs_f64() * 1000.0;
            samples_ms.push(elapsed_ms);
            digest ^= grid_digest(&grid, digest_points);
            black_box(grid.sort_state.last_sort_elapsed_ms);
        }
        CaseResult {
            name: name.to_string(),
            samples_ms,
            digest,
        }
    }

    fn make_synthetic_grid(data_rows: i32) -> VolvoxGrid {
        let mut grid = VolvoxGrid::new(100, 1280, 720, data_rows + 1, 3, 1, 0);
        grid.cells.set_text(0, 0, "group".to_string());
        grid.cells.set_text(0, 1, "number".to_string());
        grid.cells.set_text(0, 2, "code".to_string());

        for row in 1..=data_rows {
            let logical = row as u64;
            let group = format!("g{:03}", pseudo(logical, 0x91) % 256);
            let number = (pseudo(logical, 0xC7) % 1_000_000) as i64 - 500_000;
            let code = format!("{:08X}", pseudo(logical, 0xE3) as u32);
            grid.cells.set_text(row, 0, group);
            grid.cells.set_text(row, 1, number.to_string());
            grid.cells.set_text(row, 2, code);
        }

        grid
    }

    fn grid_digest(grid: &VolvoxGrid, points: &[(i32, i32)]) -> u64 {
        let mut acc = mix64(grid.rows as u64) ^ mix64(grid.cols as u64);
        for &(row, col) in points {
            if row < 0 || row >= grid.rows || col < 0 || col >= grid.cols {
                continue;
            }
            acc ^= mix_bytes(grid.cells.get_text(row, col).as_bytes());
            let pos = grid
                .row_positions
                .get(row as usize)
                .copied()
                .unwrap_or_default() as u64;
            acc ^= mix64(pos ^ ((col as u64) << 32));
        }
        acc
    }

    fn mix_bytes(bytes: &[u8]) -> u64 {
        let mut acc = 0xcbf2_9ce4_8422_2325u64;
        for &byte in bytes.iter().take(32) {
            acc ^= byte as u64;
            acc = acc.wrapping_mul(0x1000_0000_01b3);
        }
        mix64(acc ^ (bytes.len() as u64))
    }

    fn mix64(mut x: u64) -> u64 {
        x ^= x >> 30;
        x = x.wrapping_mul(0xbf58_476d_1ce4_e5b9);
        x ^= x >> 27;
        x = x.wrapping_mul(0x94d0_49bb_1331_11eb);
        x ^ (x >> 31)
    }

    fn pseudo(seed: u64, salt: u64) -> u64 {
        mix64(seed ^ salt.rotate_left(17))
    }

    fn print_case_summary(result: &CaseResult) {
        let min_ms = result
            .samples_ms
            .iter()
            .copied()
            .fold(f64::INFINITY, f64::min);
        let max_ms = result
            .samples_ms
            .iter()
            .copied()
            .fold(f64::NEG_INFINITY, f64::max);
        let mean_ms = result.samples_ms.iter().sum::<f64>() / result.samples_ms.len() as f64;
        let median_ms = median_ms(&result.samples_ms);
        let samples = result
            .samples_ms
            .iter()
            .map(|ms| format!("{ms:.2}"))
            .collect::<Vec<_>>()
            .join(", ");

        println!(
            "{name}: min={min_ms:.2} median={median_ms:.2} mean={mean_ms:.2} max={max_ms:.2} samples=[{samples}] digest={digest:016x}",
            name = result.name,
            digest = result.digest
        );
    }

    fn median_ms(samples_ms: &[f64]) -> f64 {
        let mut sorted = samples_ms.to_vec();
        sorted.sort_by(f64::total_cmp);
        let mid = sorted.len() / 2;
        if sorted.len() % 2 == 0 {
            (sorted[mid - 1] + sorted[mid]) * 0.5
        } else {
            sorted[mid]
        }
    }
}

#[cfg(feature = "demo")]
fn main() {
    app::run();
}
