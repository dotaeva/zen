# Scaffolding 目

A powerful SwiftUI navigation framework that implements the Coordinator (also known as FlowController) pattern with dot-syntax usage and minimal boilerplate. Allows easy navigation scaffolding that does not clutter the UI part of the project.

An example project using [Tuist](https://github.com/tuist/tuist) and [The Modular Architecture](https://docs.tuist.dev/en/guides/features/projects/tma-architecture) is available [here](https://github.com/dotaeva/zen-example-tma).
> **Note**: The project has been renamed to more represent its usage and to clear up consistency changes in minimal iOS versions - where Zen has supported either iOS 17+ or 18+, Scaffolding implements all updates, allowing to use one single version for the project as it grows.

## Overview

Scaffolding provides a declarative, type-safe approach to navigation in SwiftUI applications. By leveraging Swift macros and a flexible protocol system, Scaffolding eliminates common navigation pitfalls while maintaining clean separation of concerns between your views and navigation logic.

## Why should I use it?

Highly depends on how large your application is or is planning to be. If you're doing just fine with navigation living in UI layer with just `NavigationLink`, I suppose you won't find anything of interest here. If you are starting to use `NavigationStack(path:)`, you might find a benefit of predefined functions and clearer code.

If the app is large with multiple flows, you might want to try modular architecture, where this library really shines, as it allows you to slice up your navigation into modules.

### Key Features

- **Macro-driven destination generation** - Automatically generates navigation destinations from your coordinator methods
- **Three coordinator types** - Flow, Tab, and Root coordinators for different navigation patterns
- **Multiple presentation styles** - Push, sheet, and full-screen cover navigation
- **Nested routing** - Navigate through multiple coordinator layers in a single call
- **SwiftUI integration** - Uses SwiftUI's native components on the inside
- **Observable support** - Built for Swift's modern observation framework

## Getting Started

### Basic Setup

Define a coordinator using the `@Scaffoldable` macro and conform to one of the coordinator protocols. 
Then, define your routes as functions with return types `some View` for classic `View`, or `any Coordinatable` in case of embedding another `Coordinatable`. 
After defining the routes, the `@Scaffoldable` macro automatically generates a `Destinations` enum based on your specified methods. This allows you to initialize the coordinator's data property.

```swift
@Scaffoldable @Observable
final class HomeCoordinator: @MainActor FlowCoordinatable {
    var stack = FlowStack<HomeCoordinator>(root: .home)
    
    func home() -> some View { HomeView() }
    func detail(item: Item) -> some View { DetailView(item: item) }
    func settings() -> any Coordinatable { SettingsCoordinator() }
}
```

If the Coordinator you specified is the first one of the navigation tree, put it at the start of the app.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            HomeCoordinator()
                .view()
        }
    }
}
```

> **Note:** Assigning `public` modifier to the Coordinatable class exposes its routes, allowing it to be used across modules.

### Navigation

Navigate between destinations using the fluent API:

```swift
// Push navigation
coordinator.route(to: .detail(item: selectedItem))

// Modal presentation
coordinator.route(to: .settings, as: .sheet)

// Navigate with callback
coordinator.route(to: .profile) { (profileCoordinator: ProfileCoordinator) in
    profileCoordinator.setUser(currentUser)
}
```

## Coordinator Types

### FlowCoordinatable

Manages a navigation stack with push/pop operations and modal presentations.
Allowed returns types are either `some View`, or `any Coordinatable`

```swift
@Scaffoldable @Observable
final class MainCoordinator: @MainActor FlowCoordinatable {
    var stack = FlowStack<MainCoordinator>(root: .home)
    
    // Navigation methods
    func home() -> some View { HomeView() }
    func detail() -> some View { DetailView() }
    func profile() -> any Coordinatable { ProfileCoordinator() }
}
```

**Key Methods:**
- `route(to:as:)` - Navigate to a destination
- `pop()` - Pop the current view
- `popToRoot()` - Return to root view
- `popToFirst(_:)` / `popToLast(_:)` - Pop to specific destination

### TabCoordinatable

Manages tab-based navigation with support for nested coordinators in each tab.
Allowed returns types are combinations or `any Coordinatable` and `some View` for first position, optional `some View` for the second position (used for Tab's label) and from iOS 18+ you can also append `TabRole`.

```swift
@Scaffoldable @Observable
final class AppCoordinator: @MainActor TabCoordinatable {
    var tabItems = TabItems<AppCoordinator>(tabs: [.home, .profile, .search])
    
    func home() -> (any Coordinatable, some View) {
        (HomeCoordinator(), Label("Home", systemImage: "house"))
    }

    func profile() -> (any Coordinatable, some View) {
        (ProfileCoordinator(), Label("Profile", systemImage: "person"))
    }

    func search() -> (any Coordinatable, some View, TabRole) {
        (SearchCoordinator(), Label("Search", systemImage: "magnifyingglass"), .search)
    }
}
```

**Key Methods:**
- `selectFirstTab(_:)` / `selectLastTab(_:) , ...` - Select tab by destination
- `appendTab(_:)` - Add new tab
- `removeFirstTab(_:)` / `removeLastTab(_:)` - Remove tabs
### RootCoordinatable

Manages a single root view, perfect for authentication flows or app state changes.
Allowed returns types are either `some View`, or `any Coordinatable`.

```swift
@Scaffoldable @Observable
final class AuthCoordinator: @MainActor RootCoordinatable {
    var root = Root<AuthCoordinator>(root: .login)
    
    func login() -> some View { LoginView() }
    func authenticated() -> any Coordinatable { MainAppCoordinator() }
}
```

## Advanced Features

### Nested Routing

Navigate through multiple coordinator layers:

```swift
coordinator.route(to: .settings) { (settings: SettingsCoordinator) in
    settings.route(to: .accountDetails) { (account: AccountCoordinator) in
        account.setUser(currentUser)
    }
}
```

> **Note**: While Scaffolding provides a convenient API for nested routing, type safety depends on correct type annotations in the closure parameters.

### Custom View Wrapping

Customize how coordinator views are presented:

```swift
@ScaffoldingIgnored
func customize(_ view: AnyView) -> some View {
    view
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { /* Custom toolbar */ }
}
```

> **Note**: Due to the customize functions' return type being `some View`, it's being automatically tracked as well.

### Environment Integration

The coordinators are injected to each of their children. If there are multiple Coordinators of the same type in the tree of the View, the closest one to being the View's parent is used.
You can access coordinators from SwiftUI views using the environment:

```swift
struct DetailView: View {
    @Environment(MainCoordinator.self) var coordinator
    
    var body: some View {
        Button("Navigate") {
            coordinator.route(to: .nextScreen)
        }
    }
}
```

Destination object is also being injected into it's direct views through @Environment as `\.destination`. This allows you to retrieve `routeType` and `presentationType`.
If for example `DetailView` from above is being shown as `fullScreenCover`, while also being a `root` of a `FlowCoordinatable`, the values would read as

```swift
@Environment(\.destination) private var destination
...
content
    .onAppear {
        print(destination.routeType) // DestinationType.root -- the route type within the current stack
        print(destination.presentationType) // DestinationType.fullScreenCover -- the route type withing the global stack
    }
```

## Macro Attributes

### @Scaffoldable

Generates the `Destinations` enum for your coordinator. Applied to coordinator classes.

### @ScaffoldingIgnored

Excludes a method from destination generation.

```swift
@Scaffoldable @Observable
final class ExampleCoordinator: FlowCoordinatable {
    var stack = FlowStack<ExampleCoordinator>(root: .home)
    
    // Automatically tracked (returns View)
    func home() -> some View { makeHome() }
    
    // Ignored by destination generation
    @ScaffoldingIgnored
    func makeHome() -> some View { ... }
}
```

## Best Practices

1. **Coordinator ownership** - Let coordinators own their navigation state
2. **View simplicity** - Keep views focused on presentation, not navigation logic
3. **Consistent patterns** - Use the same navigation patterns throughout your app.

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 5.9+
- Xcode 15.0+

## Example Usage

```swift
// App entry point
@main
struct MyApp: App {
    @State private var appCoordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            appCoordinator.view()
        }
    }
}

// Main app coordinator
@Scaffoldable @Observable
final class AppCoordinator: RootCoordinatable {
    var root = Root<AppCoordinator>(root: .unauthenticated)
    
    func unauthenticated() -> any Coordinatable {
        UnauthenticatedCoordinator()
    }
    
    func authenticated() -> any Coordinatable {
        AuthenticatedCoordinator()
    }
}
```

