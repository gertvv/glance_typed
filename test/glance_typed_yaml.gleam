import cymbal as yaml
import glance
import glance_typed as typed

import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub fn module_to_string(module: typed.Module) -> String {
  module_to_yaml(module)
  |> yaml.encode
}

fn module_to_yaml(module: typed.Module) -> yaml.Yaml {
  yaml_block([
    #("name", yaml.string(module.name)),
    #("imports", yaml_list(module.imports, import_to_yaml)),
    #("type_aliases", yaml_list(module.type_aliases, type_alias_to_yaml)),
    #("types", yaml_list(module.custom_types, custom_type_to_yaml)),
    #("constants", yaml_list(module.constants, constant_to_yaml)),
    #("functions", yaml_list(module.functions, function_to_yaml)),
  ])
}

fn yaml_list(items: List(a), convert: fn(a) -> yaml.Yaml) -> yaml.Yaml {
  yaml.array(list.map(items, convert))
}

fn yaml_is_empty(value: yaml.Yaml) -> Bool {
  value == yaml.array([]) || value == yaml.block([])
}

fn yaml_block(entries: List(#(String, yaml.Yaml))) -> yaml.Yaml {
  entries
  |> list.filter(fn(entry) { !yaml_is_empty(entry.1) })
  |> yaml.block()
}

fn import_to_yaml(definition: typed.Definition(typed.Import)) -> yaml.Yaml {
  let import_ = definition.definition
  yaml_block(
    [
      Some(#("module", yaml.string(import_.module))),
      option.map(import_.alias, fn(alias) {
        #("alias", assignment_name_to_yaml(alias))
      }),
      Some(#("attributes", yaml_list(definition.attributes, attribute_to_yaml))),
      Some(#(
        "unqualified_types",
        yaml_list(import_.unqualified_types, unqualified_import_to_yaml),
      )),
      Some(#(
        "unqualified_values",
        yaml_list(import_.unqualified_values, unqualified_import_to_yaml),
      )),
    ]
    |> option.values,
  )
}

fn type_alias_to_yaml(
  definition: typed.Definition(typed.TypeAlias),
) -> yaml.Yaml {
  let alias = definition.definition
  yaml_block([
    #("name", yaml.string(alias.name)),
    #("type", polytype_to_yaml(alias.typ)),
    #("publicity", publicity_to_yaml(alias.publicity)),
    #("attributes", yaml_list(definition.attributes, attribute_to_yaml)),
    #("parameters", yaml_list(alias.parameters, yaml.string)),
    #("aliased", annotation_to_yaml(alias.aliased)),
  ])
}

fn custom_type_to_yaml(
  definition: typed.Definition(typed.CustomType),
) -> yaml.Yaml {
  let custom_type = definition.definition
  yaml_block([
    #("name", yaml.string(custom_type.name)),
    #("type", polytype_to_yaml(custom_type.typ)),
    #("publicity", publicity_to_yaml(custom_type.publicity)),
    #("opaque", yaml.bool(custom_type.opaque_)),
    #("attributes", yaml_list(definition.attributes, attribute_to_yaml)),
    #("parameters", yaml_list(custom_type.parameters, yaml.string)),
    #("variants", yaml_list(custom_type.variants, variant_to_yaml)),
  ])
}

fn variant_to_yaml(variant: typed.Variant) -> yaml.Yaml {
  yaml_block([
    #("name", yaml.string(variant.name)),
    #("type", polytype_to_yaml(variant.typ)),
    #(
      "fields",
      yaml_list(variant.fields, field_to_yaml(
        _,
        "annotation",
        annotation_to_yaml,
      )),
    ),
  ])
}

fn constant_to_yaml(
  definition: typed.Definition(typed.ConstantDefinition),
) -> yaml.Yaml {
  let constant = definition.definition
  yaml_block(
    [
      Some(#("name", yaml.string(constant.name))),
      Some(#("type", polytype_to_yaml(constant.typ))),
      option.map(constant.annotation, fn(annotation) {
        #("annotation", annotation_to_yaml(annotation))
      }),
      Some(#("publicity", publicity_to_yaml(constant.publicity))),
      Some(#("attributes", yaml_list(definition.attributes, attribute_to_yaml))),
      Some(#("value", expression_to_yaml(constant.value))),
    ]
    |> option.values,
  )
}

fn function_to_yaml(
  definition: typed.Definition(typed.FunctionDefinition),
) -> yaml.Yaml {
  let function = definition.definition
  yaml_block(
    [
      Some(#("name", yaml.string(function.name))),
      Some(#("type", polytype_to_yaml(function.typ))),
      Some(#("publicity", publicity_to_yaml(function.publicity))),
      Some(#("attributes", yaml_list(definition.attributes, attribute_to_yaml))),
      Some(#(
        "parameters",
        yaml_list(function.parameters, function_parameter_to_yaml),
      )),
      option.map(function.return, fn(return) {
        #("return", annotation_to_yaml(return))
      }),
      Some(#("body", yaml_list(function.body, statement_to_yaml))),
    ]
    |> option.values,
  )
}

fn typed_node(
  kind: String,
  typ: typed.Type,
  properties: List(#(String, yaml.Yaml)),
) -> yaml.Yaml {
  yaml_block([
    #("kind", yaml.string(kind)),
    #("type", type_to_yaml(typ)),
    ..properties
  ])
}

fn statement_to_yaml(statement: typed.Statement) -> yaml.Yaml {
  case statement {
    typed.Use(typ:, patterns:, function:) ->
      typed_node("use", typ, [
        #("patterns", yaml_list(patterns, pattern_to_yaml)),
        #("function", expression_to_yaml(function)),
      ])
    typed.Assignment(typ:, kind:, pattern:, annotation:, value:) ->
      typed_node(
        "assignment",
        typ,
        [
          Some(#(
            "assignment_kind",
            case kind {
              typed.Let -> "let"
              typed.LetAssert -> "let_assert"
            }
              |> yaml.string,
          )),
          Some(#("pattern", pattern_to_yaml(pattern))),
          option.map(annotation, fn(annotation) {
            #("annotation", annotation_to_yaml(annotation))
          }),
          Some(#("value", expression_to_yaml(value))),
        ]
          |> option.values,
      )
    typed.Assert(typ:, expression:, message:) ->
      typed_node(
        "assert",
        typ,
        [
          Some(#("expression", expression_to_yaml(expression))),
          option.map(message, fn(message) {
            #("message", expression_to_yaml(message))
          }),
        ]
          |> option.values,
      )
    typed.Expression(typ: _, expression:) -> expression_to_yaml(expression)
  }
}

fn expression_to_yaml(expression: typed.Expression) -> yaml.Yaml {
  case expression {
    typed.Int(typ:, value:) ->
      typed_node("int_literal", typ, [#("value", yaml.string(value))])
    typed.Float(typ:, value:) ->
      typed_node("float_literal", typ, [#("value", yaml.string(value))])
    typed.String(typ:, value:) ->
      typed_node("string_literal", typ, [#("value", yaml.string(value))])
    typed.LocalVariable(typ:, name:) ->
      typed_node("local_variable", typ, [#("name", yaml.string(name))])
    typed.Function(typ:, module:, name:, labels: _) ->
      typed_node("function", typ, [
        #("module", yaml.string(module)),
        #("name", yaml.string(name)),
      ])
    typed.Constant(typ:, module:, name:) ->
      typed_node("constant", typ, [
        #("module", yaml.string(module)),
        #("name", yaml.string(name)),
      ])
    typed.NegateInt(typ:, value:) ->
      typed_node("negate_int", typ, [#("value", expression_to_yaml(value))])
    typed.NegateBool(typ:, value:) ->
      typed_node("negate_bool", typ, [#("value", expression_to_yaml(value))])
    typed.Block(typ:, statements:) ->
      typed_node("block", typ, [
        #("statements", yaml_list(statements, statement_to_yaml)),
      ])
    typed.Panic(typ:, value:) ->
      typed_node("panic", typ, case value {
        Some(value) -> [#("value", expression_to_yaml(value))]
        None -> []
      })
    typed.Todo(typ:, value:) ->
      typed_node("todo", typ, case value {
        Some(value) -> [#("value", expression_to_yaml(value))]
        None -> []
      })
    typed.Echo(typ:, value:) ->
      typed_node("echo", typ, case value {
        Some(value) -> [#("value", expression_to_yaml(value))]
        None -> []
      })
    typed.Tuple(typ:, elements:) ->
      typed_node("tuple", typ, [
        #("elements", yaml_list(elements, expression_to_yaml)),
      ])
    typed.List(typ:, elements:, rest:) ->
      typed_node("list", typ, [
        #("elements", yaml_list(elements, expression_to_yaml)),
        ..case rest {
          Some(rest) -> [#("rest", expression_to_yaml(rest))]
          None -> []
        }
      ])
    typed.Fn(typ:, parameters:, return:, body:) ->
      typed_node(
        "fn",
        typ,
        [
          Some(#(
            "parameters",
            yaml_list(parameters, function_parameter_to_yaml),
          )),
          option.map(return, fn(return) {
            #("return", annotation_to_yaml(return))
          }),
          Some(#("body", yaml_list(body, statement_to_yaml))),
        ]
          |> option.values,
      )
    typed.RecordUpdate(
      typ:,
      module: _,
      resolved_module:,
      constructor:,
      record:,
      fields: _,
      ordered_fields:,
    ) ->
      typed_node("record_update", typ, [
        #("module", yaml.string(resolved_module)),
        #("constructor", yaml.string(constructor)),
        #("record", expression_to_yaml(record)),
        #(
          "fields",
          yaml_list(ordered_fields, fn(field) {
            case field {
              Ok(field) -> field_to_yaml(field, "value", expression_to_yaml)
              Error(typ) -> yaml_block([#("type", type_to_yaml(typ))])
            }
          }),
        ),
      ])
    typed.FieldAccess(typ:, container:, module:, variant:, label:, index:) ->
      typed_node("field_access", typ, [
        #("container", expression_to_yaml(container)),
        #("module", yaml.string(module)),
        #("variant", yaml.string(variant)),
        #("label", yaml.string(label)),
        #("index", yaml.int(index)),
      ])
    typed.Call(typ:, function:, ordered_arguments:) ->
      typed_node("call", typ, [
        #("function", expression_to_yaml(function)),
        #("arguments", yaml_list(ordered_arguments, expression_to_yaml)),
      ])
    typed.TupleIndex(typ:, tuple:, index:) ->
      typed_node("tuple_index", typ, [
        #("tuple", expression_to_yaml(tuple)),
        #("index", yaml.int(index)),
      ])
    typed.FnCapture(
      typ:,
      label:,
      function:,
      arguments_before:,
      arguments_after:,
    ) ->
      typed_node(
        "fn_capture",
        typ,
        [
          option.map(label, fn(label) { #("label", yaml.string(label)) }),
          Some(#("function", expression_to_yaml(function))),
          Some(#(
            "arguments_before",
            yaml_list(arguments_before, field_to_yaml(
              _,
              "value",
              expression_to_yaml,
            )),
          )),
          Some(#(
            "arguments_after",
            yaml_list(arguments_after, field_to_yaml(
              _,
              "value",
              expression_to_yaml,
            )),
          )),
        ]
          |> option.values,
      )
    typed.BitString(typ:, segments:) ->
      typed_node("bit_string", typ, [
        #(
          "segments",
          yaml_list(segments, fn(segment) {
            yaml_block([
              #("expression", expression_to_yaml(segment.0)),
              #(
                "options",
                yaml_list(segment.1, bit_string_segment_option_to_yaml(
                  _,
                  expression_to_yaml,
                )),
              ),
            ])
          }),
        ),
      ])
    typed.Case(typ:, subjects:, clauses:) ->
      typed_node("case", typ, [
        #("subjects", yaml_list(subjects, expression_to_yaml)),
        #("clauses", yaml_list(clauses, clause_to_yaml)),
      ])
    typed.BinaryOperator(typ:, name:, left:, right:) ->
      typed_node("binary_operator", typ, [
        #("name", yaml.string(binary_operator_to_string(name))),
        #("left", expression_to_yaml(left)),
        #("right", expression_to_yaml(right)),
      ])
  }
}

fn field_to_yaml(
  field: typed.Field(a),
  item_name: String,
  convert: fn(a) -> yaml.Yaml,
) -> yaml.Yaml {
  yaml_block(
    [
      option.map(field.label, fn(label) { #("label", yaml.string(label)) }),
      Some(#(item_name, convert(field.item))),
    ]
    |> option.values,
  )
}

fn binary_operator_to_string(operator: glance.BinaryOperator) -> String {
  case operator {
    glance.And -> "&&"
    glance.Or -> "||"
    glance.Eq -> "=="
    glance.NotEq -> "!="
    glance.LtInt -> "<"
    glance.LtEqInt -> "<="
    glance.LtFloat -> "<."
    glance.LtEqFloat -> "<=."
    glance.GtEqInt -> ">="
    glance.GtInt -> ">"
    glance.GtEqFloat -> ">=."
    glance.GtFloat -> ">."
    glance.Pipe -> "|>"
    glance.AddInt -> "+"
    glance.AddFloat -> "+."
    glance.SubInt -> "-"
    glance.SubFloat -> "-."
    glance.MultInt -> "*"
    glance.MultFloat -> "*."
    glance.DivInt -> "/"
    glance.DivFloat -> "/."
    glance.RemainderInt -> "%"
    glance.Concatenate -> "<>"
  }
}

fn clause_to_yaml(clause: typed.Clause) -> yaml.Yaml {
  yaml_block(
    [
      Some(#(
        "patterns",
        yaml_list(clause.patterns, yaml_list(_, pattern_to_yaml)),
      )),
      option.map(clause.guard, fn(guard) {
        #("guard", expression_to_yaml(guard))
      }),
      Some(#("body", expression_to_yaml(clause.body))),
    ]
    |> option.values,
  )
}

fn pattern_to_yaml(pattern: typed.Pattern) -> yaml.Yaml {
  case pattern {
    typed.PatternInt(typ:, value:) ->
      typed_node("int_pattern", typ, [#("value", yaml.string(value))])
    typed.PatternFloat(typ:, value:) ->
      typed_node("float_pattern", typ, [#("value", yaml.string(value))])
    typed.PatternString(typ:, value:) ->
      typed_node("string_pattern", typ, [#("value", yaml.string(value))])
    typed.PatternDiscard(typ:, name:) ->
      typed_node("discard_pattern", typ, [#("name", yaml.string(name))])
    typed.PatternVariable(typ:, name:) ->
      typed_node("variable_pattern", typ, [#("name", yaml.string(name))])
    typed.PatternTuple(typ:, elems:) ->
      typed_node("tuple_pattern", typ, [
        #("elements", yaml_list(elems, pattern_to_yaml)),
      ])
    typed.PatternList(typ:, elements:, tail:) ->
      typed_node(
        "list_pattern",
        typ,
        [
          Some(#("elements", yaml_list(elements, pattern_to_yaml))),
          option.map(tail, fn(tail) { #("tail", pattern_to_yaml(tail)) }),
        ]
          |> option.values,
      )
    typed.PatternAssignment(typ:, pattern:, name:) ->
      typed_node("assignment_pattern", typ, [
        #("name", yaml.string(name)),
        #("pattern", pattern_to_yaml(pattern)),
      ])
    typed.PatternConcatenate(typ:, prefix:, prefix_name:, suffix_name:) ->
      typed_node(
        "concatenate_pattern",
        typ,
        [
          Some(#("prefix", yaml.string(prefix))),
          option.map(prefix_name, fn(name) {
            #("prefix_name", assignment_name_to_yaml(name))
          }),
          Some(#("suffix_name", assignment_name_to_yaml(suffix_name))),
        ]
          |> option.values,
      )
    typed.PatternBitString(typ:, segments:) ->
      typed_node("bit_string_pattern", typ, [
        #(
          "segments",
          yaml_list(segments, fn(segment) {
            yaml_block([
              #("pattern", pattern_to_yaml(segment.0)),
              #(
                "options",
                yaml_list(segment.1, bit_string_segment_option_to_yaml(
                  _,
                  pattern_to_yaml,
                )),
              ),
            ])
          }),
        ),
      ])
    typed.PatternConstructor(
      typ:,
      module:,
      constructor:,
      arguments: _,
      ordered_arguments:,
      with_module:,
      with_spread:,
    ) ->
      typed_node("constructor_pattern", typ, [
        #("module", yaml.string(module)),
        #("constructor", yaml.string(constructor)),
        #(
          "arguments",
          yaml_list(ordered_arguments, field_to_yaml(
            _,
            "pattern",
            pattern_to_yaml,
          )),
        ),
        #("with_module", yaml.bool(with_module)),
        #("with_spread", yaml.bool(with_spread)),
      ])
  }
}

fn function_parameter_to_yaml(
  function_parameter: typed.FunctionParameter,
) -> yaml.Yaml {
  let typed.FunctionParameter(typ:, label:, name:, annotation:) =
    function_parameter
  yaml_block(
    [
      Some(#("type", type_to_yaml(typ))),
      option.map(label, fn(label) { #("label", yaml.string(label)) }),
      Some(#("name", assignment_name_to_yaml(name))),
      option.map(annotation, fn(annotation) {
        #("annotation", annotation_to_yaml(annotation))
      }),
    ]
    |> option.values,
  )
}

fn assignment_name_to_yaml(name: typed.AssignmentName) -> yaml.Yaml {
  case name {
    typed.Named(value:) -> value
    typed.Discarded(value:) -> "_" <> value
  }
  |> yaml.string
}

fn polytype_to_yaml(polytype: typed.Poly) -> yaml.Yaml {
  yaml.string(
    "("
    <> string.join(
      list.map(polytype.vars, fn(type_var_id) { int.to_string(type_var_id.id) }),
      ", ",
    )
    <> ") "
    <> type_to_string(polytype.typ),
  )
}

fn type_to_string(typ: typed.Type) -> String {
  let of_list = fn(types) { string.join(list.map(types, type_to_string), ", ") }
  case typ {
    typed.NamedType(module:, name:, parameters:) ->
      module
      <> "."
      <> name
      <> case parameters {
        [] -> ""
        _ -> "(" <> of_list(parameters) <> ")"
      }
    typed.TupleType(elements:) -> "#(" <> of_list(elements) <> ")"
    typed.FunctionType(parameters:, return:) ->
      "fn(" <> of_list(parameters) <> ") -> " <> type_to_string(return)
    typed.VariableType(ref:) -> int.to_string(ref.id)
  }
}

fn type_to_yaml(typ: typed.Type) -> yaml.Yaml {
  yaml.string(type_to_string(typ))
}

fn publicity_to_yaml(publicity: typed.Publicity) -> yaml.Yaml {
  case publicity {
    typed.Public -> "public"
    typed.Private -> "private"
  }
  |> yaml.string
}

fn annotation_to_yaml(annotation: typed.Annotation) -> yaml.Yaml {
  yaml.string(annotation_to_string(annotation))
}

fn annotation_to_string(annotation: typed.Annotation) -> String {
  let of_list = fn(annotations) {
    string.join(list.map(annotations, annotation_to_string), ", ")
  }
  case annotation {
    typed.NamedAnno(typ: _, module:, name:, parameters:) ->
      case module {
        Some(module) -> module <> "."
        None -> ""
      }
      <> name
      <> case parameters {
        [] -> ""
        _ -> "(" <> of_list(parameters) <> ")"
      }
    typed.TupleAnno(typ: _, elements:) -> "#(" <> of_list(elements) <> ")"
    typed.FunctionAnno(typ: _, parameters:, return:) ->
      "fn(" <> of_list(parameters) <> ") -> " <> annotation_to_string(return)
    typed.VariableAnno(typ: _, name:) -> name
    typed.HoleAnno(typ: _, name:) -> "_" <> name
  }
}

fn attribute_to_yaml(attribute: typed.Attribute) -> yaml.Yaml {
  yaml_block([
    #("name", yaml.string(attribute.name)),
    #("arguments", yaml_list(attribute.arguments, attribute_argument_to_yaml)),
  ])
}

fn attribute_argument_to_yaml(argument: typed.AttributeArgument) -> yaml.Yaml {
  case argument {
    typed.NameAttributeArgument(name:) ->
      yaml_block([#("name", yaml.string(name))])
    typed.StringAttributeArgument(value:) ->
      yaml_block([#("value", yaml.string(value))])
  }
}

fn unqualified_import_to_yaml(
  unqualified_import: typed.UnqualifiedImport,
) -> yaml.Yaml {
  yaml_block(
    [
      Some(#("name", yaml.string(unqualified_import.name))),
      option.map(unqualified_import.alias, fn(alias) {
        #("alias", yaml.string(alias))
      }),
    ]
    |> option.values,
  )
}

fn bit_string_segment_option_to_yaml(
  option: typed.BitStringSegmentOption(a),
  convert: fn(a) -> yaml.Yaml,
) -> yaml.Yaml {
  case option {
    typed.BytesOption -> yaml.string("bytes")
    typed.IntOption -> yaml.string("int")
    typed.FloatOption -> yaml.string("float")
    typed.BitsOption -> yaml.string("bits")
    typed.Utf8Option -> yaml.string("utf8")
    typed.Utf16Option -> yaml.string("utf16")
    typed.Utf32Option -> yaml.string("utf32")
    typed.Utf8CodepointOption -> yaml.string("utf8_codepoint")
    typed.Utf16CodepointOption -> yaml.string("utf16_codepoint")
    typed.Utf32CodepointOption -> yaml.string("utf32_codepoint")
    typed.SignedOption -> yaml.string("signed")
    typed.UnsignedOption -> yaml.string("unsigned")
    typed.BigOption -> yaml.string("big")
    typed.LittleOption -> yaml.string("little")
    typed.NativeOption -> yaml.string("native")
    typed.SizeValueOption(value) ->
      yaml_block([#("size_value", convert(value))])
    typed.SizeOption(size) -> yaml_block([#("size", yaml.int(size))])
    typed.UnitOption(unit) -> yaml_block([#("unit", yaml.int(unit))])
  }
}
