package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"

	"github.com/xhd2015/task-banner/server/dao"
	jsonrepo "github.com/xhd2015/task-banner/server/dao/json"
	"github.com/xhd2015/task-banner/server/dao/sqlite"
	"github.com/xhd2015/task-banner/server/route"
)

// TaskService handles business logic for tasks
type TaskService struct {
	repo dao.Repository
}

func NewTaskService(repo dao.Repository) *TaskService {
	return &TaskService{repo: repo}
}

// Server handles HTTP requests
type Server struct {
	service *TaskService
}

func NewServer(service *TaskService) *Server {
	return &Server{service: service}
}

func (s *Server) handleGetTasks(w http.ResponseWriter, r *http.Request) {
	tasks, err := s.service.repo.GetTasks()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tasks)
}

func (s *Server) handleGetTask(w http.ResponseWriter, r *http.Request) {
	taskIDStr := r.URL.Query().Get("id")
	if taskIDStr == "" {
		http.Error(w, "missing task id", http.StatusBadRequest)
		return
	}

	taskID, err := strconv.ParseInt(taskIDStr, 10, 64)
	if err != nil {
		http.Error(w, "invalid task id", http.StatusBadRequest)
		return
	}

	task, err := s.service.repo.GetTaskByID(taskID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if task == nil {
		http.Error(w, "task not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(task)
}

func (s *Server) handleCreateTask(w http.ResponseWriter, r *http.Request) {
	var task dao.Task
	if err := json.NewDecoder(r.Body).Decode(&task); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Reset ID to 0 to ensure auto-increment works
	task.ID = 0

	if err := s.service.repo.CreateTask(&task); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(task)
}

func (s *Server) handleUpdateTask(w http.ResponseWriter, r *http.Request) {
	var task dao.Task
	if err := json.NewDecoder(r.Body).Decode(&task); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.service.repo.UpdateTask(&task); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(task)
}

func (s *Server) handleDeleteTask(w http.ResponseWriter, r *http.Request) {
	taskIDStr := r.URL.Query().Get("id")
	if taskIDStr == "" {
		http.Error(w, "missing task id", http.StatusBadRequest)
		return
	}

	taskID, err := strconv.ParseInt(taskIDStr, 10, 64)
	if err != nil {
		http.Error(w, "invalid task id", http.StatusBadRequest)
		return
	}

	if err := s.service.repo.DeleteTask(taskID); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleAddSubTask(w http.ResponseWriter, r *http.Request) {
	parentIDStr := r.URL.Query().Get("parentId")
	if parentIDStr == "" {
		http.Error(w, "missing parent id", http.StatusBadRequest)
		return
	}

	parentID, err := strconv.ParseInt(parentIDStr, 10, 64)
	if err != nil {
		http.Error(w, "invalid parent id", http.StatusBadRequest)
		return
	}

	var task dao.Task
	if err := json.NewDecoder(r.Body).Decode(&task); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.service.repo.AddSubTask(parentID, &task); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(task)
}

func main() {
	// Choose repository implementation based on environment or flag
	var repo dao.Repository
	var err error

	// You can change this to "sqlite" to use SQLite
	// storageType := "json" // Could be from env or flag
	storageType := "sqlite"
	switch storageType {
	case "sqlite":
		repo, err = sqlite.New("tasks.db")
		if err != nil {
			log.Fatalf("Failed to initialize SQLite repository: %v", err)
		}
		defer repo.(*sqlite.Repository).Close()
	default:
		repo = jsonrepo.New("tasks.json")
	}

	service := NewTaskService(repo)
	server := NewServer(service)

	// Enable CORS
	corsMiddleware := func(next http.HandlerFunc) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			// w.Header().Set("Access-Control-Allow-Origin", "*")
			// w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			// w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

			if r.Method == "OPTIONS" {
				w.WriteHeader(http.StatusOK)
				return
			}

			next(w, r)
		}
	}

	http.HandleFunc("/tasks", corsMiddleware(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			server.handleGetTasks(w, r)
		case http.MethodPost:
			server.handleCreateTask(w, r)
		case http.MethodPut:
			server.handleUpdateTask(w, r)
		case http.MethodDelete:
			server.handleDeleteTask(w, r)
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	}))

	http.HandleFunc("/task", corsMiddleware(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			server.handleGetTask(w, r)
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	}))

	http.HandleFunc("/subtask", corsMiddleware(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			server.handleAddSubTask(w, r)
		} else {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	}))

	// serve favicon.ico
	http.HandleFunc("/favicon.ico", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "../frontend/icon.svg")
	})

	// serve frontend/index.js
	indexHandler, err := route.NewFileHandler("../frontend/build/index.js")
	if err != nil {
		log.Fatalf("Failed to initialize index handler: %v", err)
	}
	http.HandleFunc("/index.js", indexHandler.ServeHTTP)

	// serve frontend/template.html
	templateHandler, err := route.NewFileHandler("../frontend/template.html")
	if err != nil {
		log.Fatalf("Failed to initialize template handler: %v", err)
	}
	http.HandleFunc("/", templateHandler.Clone().AddProcess(func(content []byte) ([]byte, error) {
		content = bytes.ReplaceAll(content, []byte("__TITLE__"), []byte("Tasks"))
		content = bytes.ReplaceAll(content, []byte("__RENDER__"), []byte("renderRoute"))
		content = bytes.ReplaceAll(content, []byte("__COMPONENT__"), []byte("AppRoutes"))
		content = bytes.ReplaceAll(content, []byte("__INDEX_PATH__"), []byte(""))
		return content, nil
	}).ServeHTTP)

	fmt.Println("Server starting on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
