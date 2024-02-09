use clap::{Command, CommandFactory, Parser};
use clap_complete::{generate, Generator, Shell};
use std::io;

/// Generate shell completions
#[derive(Parser, Debug)]
pub struct Cli {
    shell: Shell,
}

fn print_completions<G: Generator>(gen: G, cmd: &mut Command) {
    generate(gen, cmd, cmd.get_name().to_string(), &mut io::stdout());
}

pub fn cmd_completions(argv: Vec<String>) -> i32 {
    let cli = Cli::parse_from(argv);
    print_completions(cli.shell, &mut super::Cli::command());
    0
}
