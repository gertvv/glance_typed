type Result(a, e) {
  Ok(a)
  Error(e)
}

type Foo(a) {
  Foo(value: a)
}

fn map(over result: Result(a, e), with fun: fn(a) -> b) -> Result(b, e) {
  case result {
    Ok(x) -> Ok(fun(x))
    Error(e) -> Error(e)
  }
}

pub fn main() {
  map(Ok(#(Foo(Foo(1)), Foo(1))), fn(expression_and_tokens) {
    let #(expression, _) = expression_and_tokens
    expression.value.value
  })
  Nil
}
