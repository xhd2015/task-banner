# Swift

## Padding

` .padding(.horizontal)`: 

```
Without padding:
┌────────────────────────────────┐
│□ Toggle  [WORKING|LIFE]        │
└────────────────────────────────┘

With .padding(.horizontal):
┌────────────────────────────────┐
│  □ Toggle  [WORKING|LIFE]      │
└────────────────────────────────┘
  ↑                            ↑
  Adds space here and here


Default padding space is 16
```

## @State
```swift
@State private var editingText: String = ""
```

When this value changes, SwiftUI knows to update the view

## Binding
`TextField("Task", text: $editingText)  // Can both read AND write the value`

The $ is needed when:
- You're using controls that need to both read and modify the value (like TextField)
- You want to pass the state to a child view that needs to modify it

The `TextField` contains the following declaration:

```swift
let binding: Binding<String>  // This is what $editingText creates
```

## Parameter Label Ignoring
```swift
private func renderNoteText(text: String)
-->
renderNoteText(text: "Hello")  // Must include the parameter label 'text'
```

```
private func renderNoteText(_ text: String)
-->
renderNoteText("Hello")  // No need to include the parameter label 'text'
```

## @EnvironmentObject
@EnvironmentObject is a property wrapper in SwiftUI that provides a way to share data across your entire app's view hierarchy. Here's what makes it special:

- Dependency Injection: It's a form of dependency injection where you can pass data down through the view hierarchy without explicitly passing it through each view's initializer.

- Observable: It works with ObservableObject classes, which means the views automatically update when the data changes.

- Shared State: Multiple views can access the same instance of the object, making it perfect for sharing app-wide state.

Important Property: if a parent view has an EnvironmentObject, all its descendent children automatically capture this Env.

```
Let me explain @EnvironmentObject in SwiftUI:


```

## @Published
Source: https://developer.apple.com/documentation/combine/published

## Key Differences: `@State` vs. `@ObservedObject` vs. `@StateObject`

| Feature                | `@State`                        | `@ObservedObject`              | `@StateObject`                 |
|------------------------|----------------------------------|--------------------------------|---------------------------------|
| **Purpose**           | Local, simple state for a view  | Observe an external object     | Own and manage an object       |
| **Type**              | Value type (e.g., String, Struct) | Reference type (ObservableObject) | Reference type (ObservableObject) |
| **Ownership**         | Owned by SwiftUI, tied to view  | Passed in, not owned by view   | Owned by SwiftUI, persists     |
| **Updates Triggered** | Changes to the value itself     | Changes to `@Published` properties | Changes to `@Published` properties |
| **Use Case**          | Small, view-specific data       | Shared state from outside      | Complex state owned by view    |
| **Lifecycle**         | Resets when view is recreated   | Depends on external instance   | Persists across view updates   |
| **Initialization**    | Initial value or via `init`     | Must be provided externally    | Initialized in view            |
| **Example**           | `@State var name = ""`          | `@ObservedObject var manager: Manager` | `@StateObject var manager = Manager()` |


Changing to values will update UI.
## @MainActor
```swift
@MainActor
class ObjectiveManager: ObservableObject {...}
```

@MainActor: This attribute ensures that all updates to this class occur on the main thread, which is important for SwiftUI since UI updates must happen on the main thread.

Main Thread data flow:
```
[User Action] --> [State Change] --> [SwiftUI Detects] --> [View Re-renders] --> [UI Updates]
    |                |                    |                    |                    |
    |                |                    |                    |                    |
(Button Tap)   (@State/@Published)   (Main Thread)        (body called)       (Screen refreshes)
```

What if State Change happen in non-main thread?

- You might see a runtime error like “Modifying state during view update, this will cause undefined behavior” or a crash due to thread-safety violations.

How to Handle State Changes on Non-Main Threads?
- Use Task
- `Using DispatchQueue.main`

SwiftUI's main thread model is just like nodejs' event loop:

| Feature                   | SwiftUI (`@MainActor`)       | Node.js (Event Loop)       |
|---------------------------|----------------------------|---------------------------|
| **Single-Threaded Execution** | UI updates run on the **main thread** | JavaScript runs on the **event loop** |
| **Async Task Handling**    | `Task {}` schedules async work | `Promise`, `setTimeout()` schedule async work |
| **Non-Blocking Execution** | `await` suspends execution without blocking the thread | `await` yields control to the event loop |
| **Task Queue**            | Swift concurrency runtime manages tasks | Event loop handles tasks in different phases |
| **UI Responsiveness**     | `@MainActor` ensures UI updates happen on the main thread | UI updates depend on browser rendering |

## struct vs class
| Feature                | Struct                          | Class                          |
|------------------------|----------------------------------|---------------------------------|
| **Type**              | Value type                      | Reference type                 |
| **Copy Behavior**     | Copied when passed or assigned  | Reference is passed (shared instance) |
| **Memory**            | Stored on the stack (usually)   | Stored on the heap             |
| **Inheritance**       | No inheritance                  | Supports inheritance           |
| **Mutation**          | Immutable by default (need `mutating` for methods that change properties) | Mutable by default            |
| **Deinitializers**    | No `deinit`                     | Supports `deinit`              |
| **Protocols**         | Can conform to protocols        | Can conform to protocols       |

## private(set)
make a property's setter private while keeping its getter public.

When combined with the @Published property wrapper in a class conforming to ObservableObject, it allows the property to be observed for changes externally, while restricting modification to within the class itself.

## var vs let
In Swift, var and let are used to declare variables and constants, respectively.

## extension View
Add extra modifier.

Scope: 
- default(interal): applies to all views in the same module.
- public: to all modules
- fileprivate: to current file
- private: to current scope

## Parameter label
```swift
findAdjacentTask(in tasks: [TaskItem], taskId: Int64, direction: MoveDirection) -> TaskItem?
```

The `in` is used by caller, and `tasks` is used inside the function body.

### Comparison: `@testable import App` vs. `import App`

In Swift, both `@testable import App` and `import App` are used to bring the `App` module (e.g., your main app target) into scope, but they serve different purposes, especially in testing scenarios. Below are their **in common** and **differences**.

---

In Common

- **Module Import**:
  - Both statements import the `App` module, which contains your app's code (e.g., models, services, views).
  - They allow you to use types, functions, and other declarations defined in `App`.

- **Swift Syntax**:
  - Both follow Swift’s `import` syntax and require `App` to be a valid module name (set in Xcode’s Build Settings under "Product Module Name").

- **Scope**:
  - They make `public` and `open` declarations from `App` accessible in the file where they’re used.

---

Differences

| Aspect                | `@testable import App`                          | `import App`                          |
|-----------------------|----------------------------------------------------|------------------------------------------|
| **Access Level**      | Grants access to `public`, `open`, *and* `internal` declarations in `App`. | Only grants access to `public` and `open` declarations. `internal` remains inaccessible. |
| **Purpose**           | Designed for testing, allowing deeper inspection of app internals without changing access levels. | General-purpose import for using a module’s exposed API in non-test code or external modules. |
| **Context**           | Only valid in test targets (e.g., `AppTests`). Causes a compile error in the main app target. | Valid anywhere: main app, libraries, or test targets. |
| **Encapsulation**     | Bypasses `internal` access restrictions for testing convenience. Does not affect `private` or `fileprivate`. | Respects encapsulation fully; only sees what `lifelog` explicitly exposes. |
| **Use Case**          | Writing unit tests (e.g., with XCTest or Swift Testing) to verify internal logic like `Objective.updateStatus()`. | Using `lifelog` as a dependency in another module or in app code where internal access isn’t needed. |

## JSONEncoder v.s. JSONSerialization 
In short: always use JSONEncoder.

| **Feature**            | **JSONEncoder**                     | **JSONSerialization**              |
|-----------------------|------------------------------------|------------------------------------|
| **API Level**         | High-level, Swift-native           | Low-level, Foundation-based        |
| **Type Safety**       | Yes (via `Codable`)                | No (works with `Any`)              |
| **Ease of Use**       | Easier for structured data         | More manual effort                 |
| **Flexibility**       | Less flexible, model-based         | Highly flexible, arbitrary JSON    |
| **Performance**       | Slightly slower                    | Slightly faster                    |
| **Customization**     | Via properties (e.g., key strategy)| Via options (e.g., `.prettyPrinted`)|
| **Best For**          | Modern Swift apps with models      | Legacy code or generic JSON tasks  |

Example:
```swift
request.httpBody = try JSONSerialization.data(withJSONObject: body) --> panics
request.httpBody = try JSONEncoder().encode(body) --> ok
```

## Navigation
Pattern: `NavigationLink{Text().foregroundColor(.primary)}`

```swift
  NavigationLink(destination: ObjectiveView(objective: item)
                        .environmentObject(noteManager)
                        .environmentObject(objectiveManager)
                        .environmentObject(authManager)
                        ) {
                            Text(item.content)
                                .font(.system(size: max(17 - CGFloat(indent) * 2, 12)))
                                .foregroundColor(.primary)
                        }
```

# Unit Test in Xcode project with SwiftUI
- Duplicate the default schema, append name with -test
- Define env in UNIT_TESTING=true in Run phase

# Issues
## Pull-Refresh gets cancelled
See https://github.com/xhd2015/lifelog-private/issues/244

# Interesting Cursor

## Cursor can draw text-based image!
Q: I don't like the picker, is there any alternative using a dropdown?

A: Yes, we can replace the segmented picker with a menu-style dropdown. Here's how we can modify it:
...

The result will look something like this:
```
Before (Segmented Control):
┌────────────────────────────────┐
│  □ Toggle  [WORKING|LIFE]      │
└────────────────────────────────┘

After (Dropdown):
┌────────────────────────────────┐
│  □ Toggle  [WORKING ▼]         │
└────────────────────────────────┘
              ┌─────────┐
              │ WORKING ✓│
              │ LIFE    │
              └─────────┘
```