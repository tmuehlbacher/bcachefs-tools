use clap::{Command, CommandFactory, Parser};
use clap_complete::{generate, Generator, Shell};
use std::ffi::{c_int, OsStr};
use std::io;

/// Generate shell completions
#[derive(clap::Parser, Debug)]
pub struct Cli {
    shell: Shell,
}

fn print_completions<G: Generator>(gen: G, cmd: &mut Command) {
    generate(gen, cmd, cmd.get_name().to_string(), &mut io::stdout());
}

pub fn cmd_completions(argv: Vec<&OsStr>) -> c_int {
    let cli = Cli::parse_from(argv);
    print_completions(cli.shell, &mut super::Cli::command());
    0
}
