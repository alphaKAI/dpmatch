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
