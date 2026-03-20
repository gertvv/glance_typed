import birdie
import glance
import glance_typed as typed
import glance_typed_yaml
import gleam/dict
import gleam/result
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn recursive_function_test() {
  infer_module(
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
  infer_module(
    "
    pub fn apply(f, x) {
      f(x)
    }
    ",
  )
  |> birdie.snap(title: "higher order function test")
}

pub fn list_pattern_test() {
  infer_module(
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

pub fn recursive_type_test() {
  infer_module(
    "
    pub type Tree(e) {
      Node(left: Tree(e), right: Tree(e))
      Leaf(data: e)
    }
    ",
  )
  |> birdie.snap(title: "recursive type test")
}

pub fn type_alias_test() {
  infer_module(
    "
    pub type Pair(a, b) = #(a, b)

    pub fn pair_of_pairs(p: Pair(a, b), q: Pair(a, b)) {
      #(p, q)
    }
    ",
  )
  |> birdie.snap(title: "type alias test")
}

fn infer_module(src: String) -> String {
  let assert Ok(parsed) = glance.module(src)
  let assert Ok(checked) = typed.infer_module(dict.new(), parsed, "test")
  glance_typed_yaml.module_to_string(checked)
}

pub fn import_test() {
  let assert Ok(parsed) =
    glance.module(
      "
      pub type Int
      ",
    )
  let assert Ok(prelude) =
    typed.infer_module(dict.new(), parsed, "gleam")
    |> result.map(typed.interface)

  let assert Ok(parsed) =
    glance.module(
      "
      pub type Option(e) {
        Some(e)
        None
      }

      @external(erlang, \"option\", \"map\")
      pub fn map(option: Option(a), f: fn(a) -> b) -> Option(b)
      ",
    )
  let assert Ok(option_interface) =
    typed.infer_module(dict.new(), parsed, "gleam/option")
    |> result.map(typed.interface)

  let assert Ok(parsed) =
    glance.module(
      "
      import gleam/option.{type Option, Some, None}

      pub type OptionalInt = Option(Int)

      pub fn optional_square(maybe) {
        option.map(maybe, fn(n) { n * n })
      }

      pub fn optional_double(maybe) {
        case maybe {
          Some(n) -> Some(2 * n)
          None -> None
        }
      }
      ",
    )

  let assert Ok(checked) =
    typed.infer_module(
      dict.from_list([#("gleam", prelude), #("gleam/option", option_interface)]),
      parsed,
      "example",
    )

  glance_typed_yaml.module_to_string(checked)
  |> birdie.snap(title: "import test")
}
