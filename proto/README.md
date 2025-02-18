# Task Spanner Protocol Buffers

This directory contains the Protocol Buffer definitions for the Task Spanner project. These definitions serve as the source of truth for data types and API interfaces across all components of the project.

## Prerequisites

To generate code from these proto definitions, you'll need:

1. Protocol Buffers compiler (protoc):
   ```bash
   # macOS (using Homebrew)
   brew install protobuf
   ```

2. Language-specific plugins:
   - Go:
     ```bash
     go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
     go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
     ```
   - TypeScript:
     ```bash
     # In the frontend directory
     bun add @protobuf-ts/plugin
     ```
   - Swift:
     ```bash
     brew install grpc-swift
     ```

## Directory Structure

```
proto/
├── task.proto      # Main task definitions and service interfaces
├── Makefile        # Build automation for code generation
└── README.md       # This file
```

## Generating Code

Use the provided Makefile to generate code for different platforms:

```bash
# Generate all
make all

# Generate for specific platform
make go     # Generate Go code
make ts     # Generate TypeScript code
make swift  # Generate Swift code

# Clean generated files
make clean
```

Generated files will be placed in:
- Go: `server/proto/`
- TypeScript: `frontend/src/proto/`
- Swift: `task-spanner/Generated/`

## Usage Examples

### Go Server
```go
import (
    pb "server/proto/taskspanner/v1"
)

type server struct {
    pb.UnimplementedTaskServiceServer
}
```

### TypeScript Frontend
```typescript
import { Task, TaskStatus } from '../proto/task';
```

### Swift macOS App
```swift
import TaskSpannerV1

let task = Task.with {
    $0.id = UUID().uuidString
    $0.title = "New Task"
    $0.status = .created
}
```

## Making Changes

1. Edit the proto files as needed
2. Run `make all` to regenerate code for all platforms
3. Commit both the proto files and generated code

## Best Practices

1. Always use explicit field numbers in message definitions
2. Add comments for all fields and messages
3. Use optional fields when appropriate
4. Follow the style guide: https://developers.google.com/protocol-buffers/docs/style
5. Version your APIs using package names (e.g., taskspanner.v1) 