package task

import (
	"context"
	"os"

	"github.com/xhd2015/task-banner/server/model"
	"github.com/xhd2015/task-banner/server/service/task"
	"github.com/xhd2015/task-banner/server/service/task/local_impl"
)

var service task.ITaskStorage

func init() {
	file := "tasks.json"
	envFile := os.Getenv("TASK_JSON_FILE")
	if envFile != "" {
		file = envFile
	}
	service = local_impl.New(file)
}

type ListTasksRequest struct {
	Mode model.TaskMode `json:"mode"`
}

type UpdateTaskRequest struct {
	TaskID int64             `json:"taskID"`
	Update *model.TaskUpdate `json:"update"`
}

func ListTasks(ctx context.Context, req *ListTasksRequest) ([]*model.TaskItem, error) {
	return service.LoadTasks(req.Mode)
}

func AddTask(ctx context.Context, task *model.TaskItem) (*model.TaskItem, error) {
	return service.AddTask(task)
}

func UpdateTask(ctx context.Context, req *UpdateTaskRequest) error {
	return service.UpdateTask(req.TaskID, req.Update)
}

type SaveTasksRequest struct {
	Tasks []*model.TaskItem `json:"tasks"`
}

func SaveTasks(ctx context.Context, req *SaveTasksRequest) error {
	return service.SaveTasks(req.Tasks)
}

type RemoveTaskRequest struct {
	TaskID int64 `json:"taskID"`
}

func RemoveTask(ctx context.Context, req *RemoveTaskRequest) error {
	return service.RemoveTask(req.TaskID)
}

type ExchangeOrderRequest struct {
	TaskID         int64 `json:"taskID"`
	ExchangeTaskID int64 `json:"exchangeTaskID"`
}

func ExchangeOrder(ctx context.Context, req *ExchangeOrderRequest) error {
	return service.ExchangeOrder(req.TaskID, req.ExchangeTaskID)
}

type AddTaskNoteRequest struct {
	TaskID int64  `json:"taskID"`
	Note   string `json:"note"`
}

func AddTaskNote(ctx context.Context, req *AddTaskNoteRequest) error {
	return service.AddTaskNote(req.TaskID, req.Note)
}

type UpdateTaskNoteRequest struct {
	TaskID    int64  `json:"taskID"`
	NoteIndex int    `json:"noteIndex"`
	NewText   string `json:"newText"`
}

func UpdateTaskNote(ctx context.Context, req *UpdateTaskNoteRequest) error {
	return service.UpdateTaskNote(req.TaskID, req.NoteIndex, req.NewText)
}
