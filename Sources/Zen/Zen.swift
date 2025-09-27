@attached(member, names: named(Destinations))
public macro Flow() = #externalMacro(module: "ZenMacros", type: "FlowMacro")

@attached(peer)
public macro FlowTracked() = #externalMacro(module: "ZenMacros", type: "FlowTrackedMacro")

@attached(peer)
public macro FlowIgnored() = #externalMacro(module: "ZenMacros", type: "FlowIgnoredMacro")
