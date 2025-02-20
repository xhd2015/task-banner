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
