# Zen

A powerful SwiftUI navigation framework that implements the MVVM-C (Model-View-ViewModel-Coordinator) pattern with dot-syntax usage and minimal boilerplate.

## Overview

Zen provides a declarative, type-safe approach to navigation in SwiftUI applications. By leveraging Swift macros and a flexible protocol system, Zen eliminates common navigation pitfalls while maintaining clean separation of concerns between your views and navigation logic.

### Key Features

- **Macro-driven destination generation** - Automatically generates navigation destinations from your coordinator methods
- **Three coordinator types** - Flow, Tab, and Root coordinators for different navigation patterns
- **Multiple presentation styles** - Push, sheet, and full-screen cover navigation
- **Nested routing** - Navigate through multiple coordinator layers in a single call
- **SwiftUI integration** - Seamlessly works with NavigationStack, TabView, and modal presentations
- **Observable support** - Built for Swift's modern observation framework

## Getting Started

### Basic Setup

Define a coordinator using the `@Flow` macro and conform to one of the coordinator protocols:

```swift
@Flow @Observable
final class HomeCoordinator: FlowCoordinatable {
    var stack = FlowStack<HomeCoordinator>(root: .home)
    
    func home() -> some View {
        HomeView()
    }
    
    func detail(item: Item) -> some View {
        DetailView(item: item)
    }
    
    func settings() -> any Coordinatable {
        SettingsCoordinator()
    }
}
```

The `@Flow` macro automatically generates a `Destinations` enum based on your methods that return views or coordinators.

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

```swift
@Flow @Observable
final class MainCoordinator: FlowCoordinatable {
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

```swift
@Flow @Observable
final class AppCoordinator: TabCoordinatable {
    var tabItems = TabItems<AppCoordinator>(tabs: [.home, .search, .profile])
    
    func home() -> (any Coordinatable, some View) {
        (HomeCoordinator(), Label("Home", systemImage: "house"))
    }
    
    func search() -> (any Coordinatable, some View) {
        (SearchCoordinator(), Label("Search", systemImage: "magnifyingglass"))
    }
    
    func profile() -> (any Coordinatable, some View) {
        (ProfileCoordinator(), Label("Profile", systemImage: "person"))
    }
}
```

**Key Methods:**
- `selectFirstTab(_:)` / `selectLastTab(_:)` - Select tab by destination
- `appendTab(_:)` - Add new tab
- `removeFirstTab(_:)` / `removeLastTab(_:)` - Remove tabs

### RootCoordinatable

Manages a single root view, perfect for authentication flows or app state changes.

```swift
@Flow @Observable
final class AuthCoordinator: RootCoordinatable {
    var root = Root<AuthCoordinator>(root: .login)
    
    func login() -> some View {
        LoginView()
    }
    
    func authenticated() -> any Coordinatable {
        MainAppCoordinator()
    }
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

> **Note**: While Zen provides a convenient API for nested routing, type safety depends on correct type annotations in the closure parameters.

### Custom View Wrapping

Customize how coordinator views are presented:

```swift
func customize(_ view: AnyView) -> AnyView {
    AnyView(
        view
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { /* Custom toolbar */ }
    )
}
```

### Environment Integration

Access coordinators from SwiftUI views using the environment:

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

## Macro Attributes

### @Flow

Generates the `Destinations` enum for your coordinator. Applied to coordinator classes.

### @FlowTracked

Explicitly includes a method in destination generation (useful for methods that don't return View or Coordinatable).

### @FlowIgnored

Excludes a method from destination generation.

```swift
@Flow @Observable
final class ExampleCoordinator: FlowCoordinatable {
    var stack = FlowStack<ExampleCoordinator>(root: .home)
    
    // Automatically tracked (returns View)
    func home() -> some View { HomeView() }
    
    // Explicitly tracked
    @FlowTracked
    func coordinatableDestination() -> any Coordinatable { ... }
    
    // Ignored by destination generation
    @FlowIgnored
    func generateViewMethod() -> some View { ... }
}
```

## Best Practices

1. **One coordinator per flow** - Each navigation flow should have its own coordinator
2. **Coordinator ownership** - Let coordinators own their navigation state
3. **View simplicity** - Keep views focused on presentation, not navigation logic
4. **Consistent patterns** - Use the same navigation patterns throughout your app

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
@Flow @Observable
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

---

Zen transforms SwiftUI navigation from a source of complexity into a structured, maintainable system. By separating navigation logic from view code and providing compile-time safety through macros, Zen enables you to build robust navigation flows with confidence.
