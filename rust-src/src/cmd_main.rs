use log::{error, LevelFilter};
use std::ffi::{CStr, c_int, c_char};
use crate::transform_c_args;
use crate::logger::SimpleLogger;
use crate::cmd_completions::cmd_completions;
use crate::cmd_list::cmd_list;
use crate::cmd_mount::cmd_mount;

#[no_mangle]
pub extern "C" fn rust_main(argc: c_int, argv: *const *const c_char, cmd: *const c_char) -> c_int {
    transform_c_args!(argv, argc, argv);

    log::set_boxed_logger(Box::new(SimpleLogger)).unwrap();
    log::set_max_level(LevelFilter::Warn);

    let cmd: &CStr = unsafe { CStr::from_ptr(cmd) };
    let cmd = match cmd.to_str() {
        Ok(c) => c,
        Err(e) => {
            error!("could not parse command: {}", e);
            return 1;
        }
    };

    match cmd {
        "completions" => cmd_completions(argv),
        "list" => cmd_list(argv),
        "mount" => cmd_mount(argv),
        _ => {
            error!("unknown command: {}", cmd);
            1
        }
    }
}
