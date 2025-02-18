package main

import (
	"fmt"
	"io"
	"strings"
	"text/template"
)

// Field represents a field in a message
type Field struct {
	Name       string
	Type       string
	IsRepeated bool
	IsOptional bool
}

// EnumValue represents a value in an enum
type EnumValue struct {
	Name  string
	Value int
}

// Param represents a parameter in a method
type Param struct {
	Name       string
	Type       string
	IsOptional bool
}

// SwiftTemplateData represents the data needed to generate Swift code
type SwiftTemplateData struct {
	Enums    []SwiftEnum
	Messages []SwiftMessage
	Methods  []SwiftMethod
}

type SwiftEnum struct {
	Name   string
	Values []SwiftEnumValue
}

type SwiftEnumValue struct {
	Name  string
	Value int
}

type SwiftMessage struct {
	Name   string
	Fields []SwiftField
}

type SwiftField struct {
	Name       string
	Type       string
	IsRepeated bool
	IsOptional bool
}

type SwiftMethod struct {
	Name       string
	Params     []SwiftParam
	ReturnType string
	Body       string
}

type SwiftParam struct {
	Name       string
	Type       string
	IsOptional bool
}

const swiftTemplate = `import Foundation

// MARK: - Models
{{range .Enums}}
enum {{.Name}}: Int, Codable {
    {{range .Values}}case {{.Name}} = {{.Value}}
    {{end}}
}
{{end}}

{{range .Messages}}
struct {{.Name}}: Codable, Identifiable {
    {{range .Fields}}{{if .IsRepeated}}var {{.Name}}: [{{.Type}}]{{else}}{{if .IsOptional}}var {{.Name}}: {{.Type}}?{{else}}{{if eq .Name "id"}}let{{else}}var{{end}} {{.Name}}: {{.Type}}{{end}}{{end}}
    {{end}}
}
{{end}}

// MARK: - JsonApi
class JsonApi {
    private let fileManager = FileManager.default
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let tasksFileName = "tasks.json"
    
    private var tasksFileURL: URL {
        return documentsPath.appendingPathComponent(tasksFileName)
    }
    
    // MARK: - Private Methods
    private func loadTasks() throws -> [Task] {
        guard fileManager.fileExists(atPath: tasksFileURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: tasksFileURL)
        return try JSONDecoder().decode([Task].self, from: data)
    }
    
    private func saveTasks(_ tasks: [Task]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(tasks)
        try data.write(to: tasksFileURL)
    }
    
    // MARK: - Public API
    {{range .Methods}}
    func {{.Name}}({{range $i, $p := .Params}}{{if $i}}, {{end}}{{.Name}}: {{.Type}}{{if .IsOptional}}?{{end}}{{end}}) throws -> {{.ReturnType}} {
        {{.Body}}
    }
    {{end}}
    
    // MARK: - Helper Methods
    private func findTask(id: String, in tasks: [Task]) -> Task? {
        for task in tasks {
            if task.id == id {
                return task
            }
            if let found = findTask(id: id, in: task.subTasks) {
                return found
            }
        }
        return nil
    }
    
    private func updateTasksRecursively(_ tasks: [Task], taskId: String, update: (Task) -> Task) -> [Task] {
        return tasks.map { task in
            if task.id == taskId {
                return update(task)
            }
            var updatedTask = task
            updatedTask.subTasks = updateTasksRecursively(task.subTasks, taskId: taskId, update: update)
            return updatedTask
        }
    }
    
    private func updateTasksRecursively(_ tasks: [Task], parentId: String, update: (Task) -> Task) -> [Task] {
        return tasks.map { task in
            if task.id == parentId {
                return update(task)
            }
            var updatedTask = task
            updatedTask.subTasks = updateTasksRecursively(task.subTasks, parentId: parentId, update: update)
            return updatedTask
        }
    }
    
    private func deleteTaskRecursively(_ tasks: [Task], taskId: String) -> [Task] {
        var updatedTasks = tasks
        if let index = updatedTasks.firstIndex(where: { $0.id == taskId }) {
            updatedTasks.remove(at: index)
            return updatedTasks
        }
        
        return updatedTasks.map { task in
            var updatedTask = task
            updatedTask.subTasks = deleteTaskRecursively(task.subTasks, taskId: taskId)
            return updatedTask
        }
    }
}`

func genSwift(apis []APIDefinition, w io.Writer) error {
	// Convert API definitions to Swift template data
	data := convertToSwiftData(apis)

	// Create and parse the template
	tmpl, err := template.New("swift").Parse(swiftTemplate)
	if err != nil {
		return fmt.Errorf("failed to parse template: %v", err)
	}

	// Execute the template with the API data
	if err := tmpl.Execute(w, data); err != nil {
		return fmt.Errorf("failed to execute template: %v", err)
	}

	return nil
}

func convertToSwiftData(apis []APIDefinition) SwiftTemplateData {
	data := SwiftTemplateData{}

	// Add TaskStatus enum
	data.Enums = append(data.Enums, SwiftEnum{
		Name: "TaskStatus",
		Values: []SwiftEnumValue{
			{Name: "created", Value: 0},
			{Name: "done", Value: 1},
		},
	})

	// Add Task message
	data.Messages = append(data.Messages, SwiftMessage{
		Name: "Task",
		Fields: []SwiftField{
			{Name: "id", Type: "String"},
			{Name: "title", Type: "String"},
			{Name: "startTime", Type: "Date"},
			{Name: "parentId", Type: "String", IsOptional: true},
			{Name: "subTasks", Type: "Task", IsRepeated: true},
			{Name: "status", Type: "TaskStatus"},
			{Name: "notes", Type: "String", IsRepeated: true},
		},
	})

	// Convert API methods
	for _, api := range apis {
		method := SwiftMethod{
			Name:       strings.ToLower(api.Name[:1]) + api.Name[1:], // Convert to camelCase
			ReturnType: convertResponseType(api.Response),
		}

		// Add parameters based on request type
		method.Params = extractParamsFromRequest(api.Request)
		method.Body = generateMethodBody(api.Name)
		data.Methods = append(data.Methods, method)
	}

	return data
}

func convertResponseType(protoType string) string {
	switch protoType {
	case "Task":
		return "Task"
	case "Empty":
		return "Void"
	case "ListTasksResponse":
		return "[Task]"
	default:
		return "Task?"
	}
}

func extractParamsFromRequest(requestType string) []SwiftParam {
	switch requestType {
	case "CreateTaskRequest":
		return []SwiftParam{
			{Name: "title", Type: "String"},
			{Name: "parentId", Type: "String", IsOptional: true},
		}
	case "UpdateTaskRequest":
		return []SwiftParam{
			{Name: "id", Type: "String"},
			{Name: "title", Type: "String", IsOptional: true},
			{Name: "status", Type: "TaskStatus", IsOptional: true},
		}
	case "AddNoteRequest":
		return []SwiftParam{
			{Name: "taskId", Type: "String"},
			{Name: "note", Type: "String"},
		}
	case "GetTaskRequest":
		return []SwiftParam{
			{Name: "id", Type: "String"},
		}
	case "DeleteTaskRequest":
		return []SwiftParam{
			{Name: "id", Type: "String"},
		}
	case "ListTasksRequest":
		return []SwiftParam{}
	default:
		return nil
	}
}

func generateMethodBody(methodName string) string {
	switch methodName {
	case "ListTasks":
		return "return try loadTasks()"
	case "GetTask":
		return `let tasks = try loadTasks()
        return findTask(id: id, in: tasks)`
	case "CreateTask":
		return `var tasks = try loadTasks()
        let newTask = Task(
            id: UUID().uuidString,
            title: title,
            startTime: Date(),
            parentId: parentId,
            subTasks: [],
            status: .created,
            notes: []
        )
        
        if let parentId = parentId {
            tasks = updateTasksRecursively(tasks, parentId: parentId) { parent in
                var updatedParent = parent
                updatedParent.subTasks.append(newTask)
                return updatedParent
            }
        } else {
            tasks.append(newTask)
        }
        
        try saveTasks(tasks)
        return newTask`
	case "UpdateTask":
		return `var tasks = try loadTasks()
        var updatedTask: Task?
        
        tasks = updateTasksRecursively(tasks, taskId: id) { task in
            var updated = task
            if let newTitle = title {
                updated.title = newTitle
            }
            if let newStatus = status {
                updated.status = newStatus
            }
            updatedTask = updated
            return updated
        }
        
        try saveTasks(tasks)
        return updatedTask`
	case "AddNote":
		return `var tasks = try loadTasks()
        var updatedTask: Task?
        
        tasks = updateTasksRecursively(tasks, taskId: taskId) { task in
            var updated = task
            updated.notes.append(note)
            updatedTask = updated
            return updated
        }
        
        try saveTasks(tasks)
        return updatedTask`
	case "DeleteTask":
		return `var tasks = try loadTasks()
        tasks = deleteTaskRecursively(tasks, taskId: id)
        try saveTasks(tasks)
        return ()`
	default:
		return `fatalError("Method '\(methodName)' not implemented")`
	}
}
