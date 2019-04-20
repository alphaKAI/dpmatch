module dpmatch.parser;
import pegged.grammar;
import std.stdio, std.format, std.array;
import std.algorithm, std.string, std.traits;
import dpmatch.util;

enum DPMatchGrammar = `
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
`;

mixin(grammar(DPMatchGrammar));

enum ASTElemType {
  tPatternList,
  tPatternListElement,
  tPattern,
  tVariantPattern,
  tVariantPatternBindings,
  tVariantPatternArgs,
  tVariantPatternName,
  tPatternHandler
}

interface ASTElement {
  const ASTElemType etype();
}

class PatternHandler : ASTElement {
  string code;
  this(string code) {
    this.code = code;
  }

  const ASTElemType etype() {
    return ASTElemType.tPatternHandler;
  }
}

class VariantPatternName : ASTElement {
  string name;
  this(string name) {
    this.name = name;
  }

  const ASTElemType etype() {
    return ASTElemType.tVariantPatternName;
  }

  string getNameStr() {
    return this.name;
  }
}

class VariantPatternBindings : ASTElement {
  VariantPatternName[] bindings;
  this(VariantPatternName[] bindings) {
    this.bindings = bindings;
  }

  const ASTElemType etype() {
    return ASTElemType.tVariantPatternBindings;
  }

  string[] bindingsStr() {
    return this.bindings.map!(binding => binding.getNameStr()).array;
  }
}

class VariantPatternArgs : ASTElement {
  VariantPattern[] args;
  this(VariantPattern[] args) {
    this.args = args;
  }

  const ASTElemType etype() {
    return ASTElemType.tVariantPatternArgs;
  }
}

enum PatternType {
  pVariantPattern
}

interface Pattern : ASTElement {
  const PatternType ptype();
}

class VariantPattern : Pattern {
  VariantPatternName vp_name;
  VariantPatternBindings bindings;

  this(VariantPatternName vp_name, VariantPatternBindings bindings) {
    this.vp_name = vp_name;
    this.bindings = bindings;
  }

  string getNameStr() {
    return this.vp_name.name;
  }

  const ASTElemType etype() {
    return ASTElemType.tVariantPattern;
  }

  const PatternType ptype() {
    return PatternType.pVariantPattern;
  }
}

class PatternListElement : ASTElement {
  Pattern pattern;
  PatternHandler handler;
  this(Pattern pattern, PatternHandler handler) {
    this.pattern = pattern;
    this.handler = handler;
  }

  const ASTElemType etype() {
    return ASTElemType.tPatternListElement;
  }
}

class PatternList : ASTElement {
  PatternListElement[] list;
  this(PatternListElement[] list) {
    this.list = list;
  }

  const ASTElemType etype() {
    return ASTElemType.tPatternList;
  }

  PatternListElement[] getElems() {
    return this.list;
  }
}

ASTElement buildAST(ParseTree p) {
  /*
  if (!__ctfe) {
    writeln("p.name : ", p.name);
  }
  */

  final switch (p.name) {
  case "DPMATCH":
    return buildAST(p.children[0]);
  case "DPMATCH.PatternList":
    PatternListElement[] list;
    foreach (child; p.children) {
      PatternListElement elem = cast(PatternListElement)buildAST(child);
      if (elem is null) {
        throw new Error("Error in %s!".format(p.name));
      }
      list ~= elem;
    }
    return new PatternList(list);
  case "DPMATCH.PatternListElement":
    Pattern pattern = cast(Pattern)buildAST(p.children[0]);
    if (pattern is null) {
      throw new Error("Error in %s!".format(p.name));
    }
    PatternHandler handler = cast(PatternHandler)buildAST(p.children[1]);
    if (handler is null) {
      throw new Error("Error in %s!".format(p.name));
    }
    return new PatternListElement(pattern, handler);
  case "DPMATCH.Pattern":
    return buildAST(p.children[0]);
  case "DPMATCH.VariantPattern":
    VariantPatternBindings bindings;
    if (p.children.length == 2) {
      bindings = cast(VariantPatternBindings)buildAST(p.children[1]);
      if (bindings is null) {
        throw new Error("Error in %s!".format(p.name));
      }
    } else {
      bindings = new VariantPatternBindings([]);
    }
    VariantPatternName vpn = cast(VariantPatternName)buildAST(p.children[0]);

    if (vpn is null) {
      throw new Error("Error in %s!".format(p.name));
    }
    return new VariantPattern(vpn, bindings);
  case "DPMATCH.VariantPatternBindings":
    VariantPatternName[] bindings;
    foreach (child; p.children) {
      VariantPatternName v = cast(VariantPatternName)buildAST(child);
      if (v is null) {
        throw new Error("Error in %s!".format(p.name));
      }
      bindings ~= v;
    }
    return new VariantPatternBindings(bindings);
  case "DPMATCH.VariantPatternName":
    return new VariantPatternName(p.matches[0]);
  case "DPMATCH.VariantPatternArgs":
    VariantPattern[] args;
    foreach (child; p.children) {
      VariantPattern arg = cast(VariantPattern)buildAST(child);
      if (arg is null) {
        throw new Error("Error in %s!".format(p.name));
      }
      args ~= arg;
    }
    return new VariantPatternArgs(args);
  case "DPMATCH.PatternHandler":
    return new PatternHandler(p.matches[0]);
  }
}

string compileForDADT(DADTTypeType, alias __INTERNAL_PATTERN_MATCH_ARGUMENT)(
    const ASTElement node, string INTERNAL_PATTERN_MATCH_ARGUMENT_NAME) {
  if (node.etype != ASTElemType.tPatternList) {
    throw new Error("compileForDADT accept only PatternList");
  }
  PatternList list = cast(PatternList)node;
  PatternListElement[] elems = list.getElems();
  string elems_code;

  string[] dadttypes;
  foreach (elem; __traits(allMembers, DADTTypeType)) {
    dadttypes ~= elem;
  }
  dadttypes.sort!"a<b";
  string[] pattern_types;

  foreach (PatternListElement elem; elems) {
    if (elem.pattern.ptype != PatternType.pVariantPattern) {
      throw new Error("Error: compileForDADT only support pVariantPattern currently.");
    }
    VariantPattern vp = cast(VariantPattern)elem.pattern;
    pattern_types ~= vp.getNameStr();
  }
  pattern_types.sort!"a<b";

  if (pattern_types != dadttypes) {
    string cases_msg = dadttypes.filter!(dadttype => !pattern_types.canFind(dadttype))
      .array
      .map!(_case => "  %s".format(_case))
      .join("\n");

    throw new Error(
        "This pattern match is not exhausitve.\nHere is an example of a case that is not matched:\n%s".format(
        cases_msg));
  }

  // code generation
  foreach (PatternListElement elem; elems) {
    VariantPattern vp = cast(VariantPattern)elem.pattern;
    VariantPatternBindings bindings = vp.bindings;
    VariantPatternName vpn = vp.vp_name;

    string constructor_name = vpn.getNameStr();
    string[] constructor_args;

    foreach (arg; TemplateArgsOf!(typeof(__INTERNAL_PATTERN_MATCH_ARGUMENT))) {
      constructor_args ~= arg.stringof;
    }

    string[] handler_args = bindings.bindingsStr().map!(arg => "\"%s\"".format(arg)).array;
    string handler_body = elem.handler.code;
    const constructor_str = "%s!(%s)".format(constructor_name, constructor_args.join(", "));

    elems_code ~= `
  if ((cast(#{constructor_str}#)#{INTERNAL_PATTERN_MATCH_ARGUMENT_NAME}#) !is null) {
    auto __INTERNAL_VALUE_CASTED = cast(#{constructor_str}#)#{INTERNAL_PATTERN_MATCH_ARGUMENT_NAME}#;
    import std.algorithm, std.array, std.string;
    import dpmatch.util;
    enum original_members = getOriginalMembers!(#{constructor_str}#);
    enum string[] handler_args = [#{handler_args}#];
    enum binding_args = {
      string[] binding_args;
      foreach (i, member; original_members) {
        binding_args ~= "typeof(%s) %s".format("__INTERNAL_VALUE_CASTED." ~ member, handler_args[i]);
      }
      return binding_args;
    }();
    enum call_args = original_members.map!(member => "__INTERNAL_VALUE_CASTED." ~ member).array.join(", ");

    mixin(q{enum __INTERNAL_BINDING = (%s) #{handler_body}#;}.format(binding_args.join(", ")));
    mixin("enum __INTERNAL_BINDING_CALL = \"__INTERNAL_BINDING(%s)\";".format(call_args));
    import std.traits;
    static if (is(ReturnType!(__INTERNAL_BINDING) == void)) {
      mixin("%s;".format(__INTERNAL_BINDING_CALL));
      return;
    } else {
      mixin("return %s;".format(__INTERNAL_BINDING_CALL));
    }
  }
`.patternReplaceWithTable([
        "constructor_str": constructor_str,
        "INTERNAL_PATTERN_MATCH_ARGUMENT_NAME": INTERNAL_PATTERN_MATCH_ARGUMENT_NAME,
        "handler_body": handler_body,
        "handler_args": handler_args.join(", ")
        ]);
  }

  return `() {
%s
  throw new Exception("Should not reach here");
}();`.format(elems_code);
}

string patternMatchADT(alias __INTERNAL_PATTERN_MATCH_ARGUMENT, DADTTypeType, string def)() {
  enum p = DPMATCH(def);
  enum code = buildAST(p).compileForDADT!(DADTTypeType,
        __INTERNAL_PATTERN_MATCH_ARGUMENT)(__INTERNAL_PATTERN_MATCH_ARGUMENT.stringof);
  return code;
}

string patternMatchADTReturn(alias __INTERNAL_PATTERN_MATCH_ARGUMENT, DADTTypeType, string def)() {
  enum p = DPMATCH(def);
  enum code = buildAST(p).compileForDADT!(DADTTypeType,
        __INTERNAL_PATTERN_MATCH_ARGUMENT)(__INTERNAL_PATTERN_MATCH_ARGUMENT.stringof);
  return "return %s".format(code);
}

string patternMatchADTBind(alias __INTERNAL_PATTERN_MATCH_ARGUMENT,
    DADTTypeType, string def, string target)() {
  enum p = DPMATCH(def);
  enum code = buildAST(p).compileForDADT!(DADTTypeType,
        __INTERNAL_PATTERN_MATCH_ARGUMENT)(__INTERNAL_PATTERN_MATCH_ARGUMENT.stringof);
  return "auto %s = %s".format(target, code);
}
