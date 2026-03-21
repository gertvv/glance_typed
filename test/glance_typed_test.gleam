import birdie
import glance
import glance_typed as typed
import glance_typed_yaml
import gleam/dict
import gleeunit

pub fn main() {
  gleeunit.main()
}

fn infer_with(
  dependencies: dict.Dict(String, typed.ModuleInterface),
  source: String,
  module_name: String,
) -> typed.Module {
  let assert Ok(parsed) = glance.module(source)
  let assert Ok(checked) = typed.infer_module(dependencies, parsed, module_name)
  checked
}

fn infer(source: String) -> typed.Module {
  infer_with(dict.new(), source, "test")
}

fn infer_interface(
  dependencies: dict.Dict(String, typed.ModuleInterface),
  source: String,
  module_name: String,
) -> typed.ModuleInterface {
  typed.interface(infer_with(dependencies, source, module_name))
}

fn infer_yaml(source: String) -> String {
  glance_typed_yaml.module_to_string(infer(source))
}

pub fn recursive_function_test() {
  infer_yaml(
    "
    pub fn countdown(n) {
      case n {
        0 -> 0
        _ -> countdown(n - 1)
      }
    }
    ",
  )
  |> birdie.snap(title: "recursive function test")
}

pub fn higher_order_function_test() {
  infer_yaml(
    "
    pub fn apply(f, x) {
      f(x)
    }
    ",
  )
  |> birdie.snap(title: "higher order function test")
}

pub fn positional_pattern_with_spread_test() {
  infer_yaml(
    "
    pub type Triple(a) {
      Triple(a: a, b: a, c: a)
    }

    pub fn first(t: Triple(a)) {
      case t {
        Triple(x, ..) -> x
      }
    }
    ",
  )
  |> birdie.snap(title: "positional pattern with spread test")
}

pub fn list_pattern_test() {
  infer_yaml(
    "
    pub fn head(list) {
      case list {
        [] -> 0
        [x, ..] -> x
      }
    }
    ",
  )
  |> birdie.snap(title: "list pattern test")
}

pub fn recursive_custom_type_test() {
  infer_yaml(
    "
    pub type Tree(e) {
      Node(left: Tree(e), right: Tree(e))
      Leaf(data: e)
    }
    ",
  )
  |> birdie.snap(title: "recursive custom type test")
}

pub fn type_alias_test() {
  infer_yaml(
    "
    pub type Pair(a, b) = #(a, b)

    pub fn pair_of_pairs(p: Pair(a, b), q: Pair(a, b)) {
      #(p, q)
    }
    ",
  )
  |> birdie.snap(title: "type alias test")
}

fn option_dependencies() -> dict.Dict(String, typed.ModuleInterface) {
  let prelude = infer_interface(dict.new(), "pub type Int", "gleam")
  let option_interface =
    infer_interface(
      dict.new(),
      "
      pub type Option(e) {
        Some(e)
        None
      }

      @external(erlang, \"option\", \"map\")
      pub fn map(option: Option(a), f: fn(a) -> b) -> Option(b)
      ",
      "gleam/option",
    )
  dict.from_list([#("gleam", prelude), #("gleam/option", option_interface)])
}

pub fn field_access_test() {
  infer_yaml(
    "
    pub type Box(a) {
      Box(value: a)
    }

    pub fn get_value(b: Box(a)) {
      b.value
    }
    ",
  )
  |> birdie.snap(title: "field access test")
}

pub fn nested_field_access_test() {
  infer_yaml(
    "
    type Foo(a) {
      Foo(value: a)
    }

    pub fn get() {
      let a = Foo(Foo(1))
      a.value.value
    }
    ",
  )
  |> birdie.snap(title: "nested field access test")
}

pub fn pipe_with_labelled_arg_test() {
  infer_yaml(
    "
    pub fn write(to file, data string) {
      panic
    }
    pub fn get() {
      123
      |> write(to: \"foo\")
    }
    ",
  )
  |> birdie.snap(title: "pipe with labelled arg test")
}

pub fn fn_arg_field_access_test() {
  infer_yaml(
    "
    pub type Foo(a) {
      Foo(value: a)
    }

    fn apply(x: a, f: fn(a) -> b) -> b {
      f(x)
    }

    pub fn main() {
      apply(Foo(1), fn(foo) { foo.value })
    }
    ",
  )
  |> birdie.snap(title: "fn arg field access test")
}

pub fn imported_type_alias_test() {
  infer_with(
    option_dependencies(),
    "
    import gleam/option.{type Option}

    pub type OptionalInt = Option(Int)
    ",
    "example",
  )
  |> glance_typed_yaml.module_to_string
  |> birdie.snap(title: "imported type alias test")
}

pub fn imported_function_call_test() {
  infer_with(
    option_dependencies(),
    "
    import gleam/option

    pub fn optional_square(maybe) {
      option.map(maybe, fn(n) { n * n })
    }
    ",
    "example",
  )
  |> glance_typed_yaml.module_to_string
  |> birdie.snap(title: "imported function call test")
}

pub fn imported_constructor_pattern_test() {
  // TODO None -> None is being labeled as "function"
  // maybe it should be "constant" or something else?
  infer_with(
    option_dependencies(),
    "
    import gleam/option.{Some, None}

    pub fn optional_double(maybe) {
      case maybe {
        Some(n) -> Some(2 * n)
        None -> None
      }
    }
    ",
    "example",
  )
  |> glance_typed_yaml.module_to_string
  |> birdie.snap(title: "imported constructor pattern test")
}
