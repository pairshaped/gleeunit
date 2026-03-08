import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Configuration for the test runner.
///
/// Use `default_config()` for stock gleeunit behaviour (sequential),
/// then override with builder functions to expose EUnit options.
///
pub type Config {
  Config(
    /// Run tests in parallel via EUnit's `{inparallel, Tests}`.
    /// Default: False (sequential, same as stock gleeunit).
    parallel: Bool,
    /// Cap parallel concurrency via `{inparallel, N, Tests}`.
    /// None means unlimited. Only applies when parallel is True.
    max_concurrency: Option(Int),
    /// EUnit's `{scale_timeouts, N}`. Default: 10.
    scale_timeouts: Int,
  )
}

/// Returns the default config: sequential execution, matching stock gleeunit.
///
pub fn default_config() -> Config {
  Config(parallel: False, max_concurrency: None, scale_timeouts: 10)
}

/// Set parallel execution mode.
///
pub fn with_parallel(config: Config, parallel: Bool) -> Config {
  Config(..config, parallel: parallel)
}

/// Set maximum concurrency for parallel mode.
/// None means unlimited. Only applies when parallel is True.
///
pub fn with_max_concurrency(
  config: Config,
  max_concurrency: Option(Int),
) -> Config {
  Config(..config, max_concurrency: max_concurrency)
}

/// Set the EUnit timeout scale multiplier.
///
pub fn with_scale_timeouts(config: Config, scale_timeouts: Int) -> Config {
  Config(..config, scale_timeouts: scale_timeouts)
}

/// Find and run all test functions for the current project using Erlang's EUnit
/// test framework, or a custom JavaScript test runner.
///
/// Any Erlang or Gleam function in the `test` directory with a name ending in
/// `_test` is considered a test function and will be run.
///
/// A test that panics is considered a failure.
///
/// This uses sequential execution, equivalent to `run(default_config())`.
///
pub fn main() -> Nil {
  run(default_config())
}

/// Run tests with the given configuration.
///
/// On JavaScript targets, parallel settings are ignored and tests run
/// sequentially.
///
pub fn run(config: Config) -> Nil {
  do_run(config)
}

@external(javascript, "./gleeunit_ffi.mjs", "main")
fn do_run(config: Config) -> Nil {
  let options = [
    Verbose,
    NoTty,
    Report(#(GleeunitProgress, [Colored(True)])),
    ScaleTimeouts(config.scale_timeouts),
  ]

  let modules =
    find_files(matching: "**/*.{erl,gleam}", in: "test")
    |> list.map(gleam_to_erlang_module_name)
    |> list.map(dangerously_convert_string_to_atom(_, Utf8))

  let result = case config.parallel, config.max_concurrency {
    True, Some(max) -> run_eunit_parallel_capped(modules, max, options)
    True, None -> run_eunit_parallel(modules, options)
    False, _ -> run_eunit(modules, options)
  }

  let code = case result {
    Ok(_) -> 0
    Error(_) -> 1
  }
  halt(code)
}

@external(erlang, "erlang", "halt")
fn halt(a: Int) -> Nil

fn gleam_to_erlang_module_name(path: String) -> String {
  case string.ends_with(path, ".gleam") {
    True ->
      path
      |> string.replace(".gleam", "")
      |> string.replace("/", "@")

    False ->
      path
      |> string.split("/")
      |> list.last
      |> result.unwrap(path)
      |> string.replace(".erl", "")
  }
}

@external(erlang, "gleeunit_ffi", "find_files")
fn find_files(matching matching: String, in in: String) -> List(String)

type Atom

type Encoding {
  Utf8
}

@external(erlang, "erlang", "binary_to_atom")
fn dangerously_convert_string_to_atom(a: String, b: Encoding) -> Atom

type ReportModuleName {
  GleeunitProgress
}

type GleeunitProgressOption {
  Colored(Bool)
}

type EunitOption {
  Verbose
  NoTty
  Report(#(ReportModuleName, List(GleeunitProgressOption)))
  ScaleTimeouts(Int)
}

@external(erlang, "gleeunit_ffi", "run_eunit")
fn run_eunit(a: List(Atom), b: List(EunitOption)) -> Result(Nil, a)

@external(erlang, "gleeunit_ffi", "run_eunit_parallel")
fn run_eunit_parallel(a: List(Atom), b: List(EunitOption)) -> Result(Nil, a)

@external(erlang, "gleeunit_ffi", "run_eunit_parallel_capped")
fn run_eunit_parallel_capped(
  a: List(Atom),
  b: Int,
  c: List(EunitOption),
) -> Result(Nil, a)
