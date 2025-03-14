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


# Add to head
research first: task-spanner/task-spanner is for MacOS,server is for backend. I want to change the task adding logic: when a new item is added, it should be insert into head, not append to tail. tell me how you will modify code in task-spanner/task-spanner and server to achieve this. no test needed, I will test myself.