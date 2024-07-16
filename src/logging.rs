use env_logger::WriteStyle;
use log::LevelFilter;

pub fn setup(verbose: u8, color: bool) {
    let level_filter = match verbose {
        0 => LevelFilter::Off,
        1 => LevelFilter::Info,
        2 => LevelFilter::Debug,
        _ => LevelFilter::Trace,
    };

    let style = if color {
        WriteStyle::Always
    } else {
        WriteStyle::Never
    };

    env_logger::Builder::new()
        .filter_level(level_filter)
        .write_style(style)
        .parse_env("BCACHEFS_LOG")
        .init();
}
