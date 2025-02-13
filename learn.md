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