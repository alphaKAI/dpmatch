import std.stdio;
import dpmatch;
import dadt;

mixin(genCodeFromSource(`
type Option(T) =
| Some of T
| None
[@@deriving show, eq]
`));

import std.traits;

Option!U opt_map(F, T = Parameters!F[0], U = ReturnType!F)(Option!T v_opt, F f)
    if (isCallable!F && arity!F == 1) {
  mixin(patternMatchADTReturn!(v_opt, OptionType, q{
    | Some (x) -> <{ return some(f(x)); }>
    | None -> <{ return none!T(); }>
  }));
}

Option!U opt_bind(F, T = Parameters!F[0], RET = ReturnType!F, U = TemplateArgsOf!RET[0])(
    Option!T v_opt, F f) if (isCallable!F && arity!F == 1) {
  mixin(patternMatchADTReturn!(v_opt, OptionType, q{
    | Some (x) -> <{ return f(x); }>
    | None -> <{ return none!U; }>
  }));
}

T opt_default(T)(Option!T v_opt, T _default) {
  mixin(patternMatchADTReturn!(v_opt, OptionType, q{
    | Some (x) -> <{ return x; }>
    | None -> <{ return _default; }>
  }));
}

void opt_may(F, T = Parameters!F[0])(Option!T v_opt, F f)
    if (isCallable!F && arity!F == 1) {
  mixin(patternMatchADTReturn!(v_opt, OptionType, q{
    | Some (x) -> <{ f(x); }>
    | None -> <{ }>
  }));
}

void main() {
  writeln("opt_default(some(10), 0): ", opt_default(some(10), 0));
  writeln("opt_default(none!int, 0): ", opt_default(none!int, 0));

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

  int i1 = 10;
  int i2 = 0;
  Option!int opt_ans = (i2 == 0 ? none!int : some(i2)).opt_map((int d) => i1 / d);
  writeln(show_Option(opt_ans)); // None!(int)

  i2 = 2;

  opt_ans = (i2 == 0 ? none!int : some(i2)).opt_map((int d) => i1 / d);
  writeln(show_Option(opt_ans)); // Some!(int)(5)
}
