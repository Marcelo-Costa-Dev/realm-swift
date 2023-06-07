@attached(conformance)
@attached(member, names: named(_rlmProperties))
//@attached(memberAttribute)
public macro RealmModel() -> () = #externalMacro(module: "RealmMacroMacros", type: "RealmObjectMacro")
