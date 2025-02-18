# Project
Manage user's tasks

Directory:
- task-spanner: swift project

Requirement:
- show a floating banner on top of the screen, show a list of active tasks working on
- the spanner show persist regardless of which app is open


# Definition of API
Choice: Protobuf.

Recommendation from Cursor:

- If you want maximum performance and strong typing across all platforms: Use Protocol Buffers
- If you need flexibility and real-time features: Use GraphQL
- If your stack is primarily TypeScript: Use tRPC
- If you want simplicity and direct type generation: Use TypeScript as source of truth

For your specific case with Swift, Go, and TypeScript, I would recommend Protocol Buffers because:
- It has excellent support for all three languages
- It provides strong typing and validation
- The schema is clear and maintainable
- Code generation is reliable and well-tested
- It has good performance characteristics
- It supports both REST and gRPC protocols
```