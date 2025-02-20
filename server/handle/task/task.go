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

func ListTasks(ctx context.Context, req *ListTasksRequest) ([]*model.TaskItem, error) {
	return service.LoadTasks(req.Mode)
}
