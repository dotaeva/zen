@attached(member, names: named(Destinations))
public macro Scaffoldable() = #externalMacro(module: "ScaffoldingMacros", type: "ScaffoldableMacro")

@attached(peer)
public macro ScaffoldingTracked() = #externalMacro(module: "ScaffoldingMacros", type: "ScaffoldingTrackedMacro")

@attached(peer)
public macro ScaffoldingIgnored() = #externalMacro(module: "ScaffoldingMacros", type: "ScaffoldingIgnoredMacro")
