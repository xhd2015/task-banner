package dao

import "time"

// Task represents a task in the system
type Task struct {
	ID        int64     `json:"id"`
	Title     string    `json:"title"`
	Status    string    `json:"status"`
	StartTime time.Time `json:"startTime"`
	ParentID  *int64    `json:"parentId,omitempty"`
	SubTasks  []Task    `json:"subTasks,omitempty"`
}

// Repository defines the interface for task storage
type Repository interface {
	GetTasks() ([]Task, error)
	GetTaskByID(id int64) (*Task, error)
	CreateTask(task *Task) error
	UpdateTask(task *Task) error
	DeleteTask(id int64) error
	AddSubTask(parentID int64, task *Task) error
}
