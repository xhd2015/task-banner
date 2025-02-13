# Swift

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