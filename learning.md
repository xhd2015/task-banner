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