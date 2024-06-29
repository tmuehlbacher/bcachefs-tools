use env_logger::WriteStyle;
use log::LevelFilter;

pub fn setup(quiet: bool, verbose: u8, color: bool) {
    let level_filter = if quiet {
        LevelFilter::Off
    } else {
        match verbose {
            0 => LevelFilter::Info,
            1 => LevelFilter::Debug,
            _ => LevelFilter::Trace,
        }
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
