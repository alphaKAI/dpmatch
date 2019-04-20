# DPMATCH -- Pattern Matching for D

## About
Pattern Mathing for D.  
Parsing and compile pattern matching expression into D code in Compile Time.  

## Features

[*] ADT Pattern -- you can use pattern matching for ADT(you have to use [DADT](https://github.com/alphaKAI/dadt together))
[] List(Array) Pattern -- WIP
[] Range Pattern -- WIP
[] Tuple Pattern -- WIP


## Example

### Option

```d
import std.stdio;
import dpmatch;
import dadt;

mixin(genCodeFromSource(`
type Option(T) =
| Some of T
| None
[@@deriving show, eq]
`));

int get_default(Option!int v_opt, int _default) {
  mixin(patternMatchADTReturn!(v_opt, OptionType, q{
    | Some (x) -> <{ return x; }>
    | None -> <{ return _default; }>
  }));
}

void main() {
  writeln("get_default(some(10), 0): ", get_default(some(10), 0));
  writeln("get_default(none!int, 0): ", get_default(none!int, 0));

  Option!int v = some(100);
  mixin(patternMatchADTBind!(v, OptionType, q{
    | Some (x) -> <{ return x; }>
    | None -> <{ return 200; }>
  }, "ret"));

  writeln(ret);

  v = none!int();
  mixin(patternMatchADT!(v, OptionType, q{
    | Some (x) -> <{ writeln("Some with ", x); }>
    | None -> <{ writeln("None"); }>
  }));
}
```

## Syntax

```
DPMATCH:
  PatternList < PatternListElement+
  PatternListElement < "|" Pattern "->" PatternHandler

  Pattern < VariantPattern
  VariantPattern < VariantPatternName VariantPatternBindings
  VariantPatternBindings <  (:"(" VariantPatternName ("," VariantPatternName)* :")")?
  VariantPatternArgs < "()" / :"(" VariantPattern ("," VariantPattern)* :")"
  VariantPatternName <~ !Keyword [a-zA-Z_] [a-zA-Z0-9_]*

  PatternHandler <~ :"<""{" (!"}>" .)* "}":">"

  Keyword <~ "match"
```

## LICENSE
DPMATCH is released under the MIT License.  
Please see LICENSE for details.  
Copyright (C) 2019 Akihiro Shoji  