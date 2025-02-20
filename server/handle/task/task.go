package task

import (
	"context"

	"github.com/xhd2015/task-banner/server/model"
	"github.com/xhd2015/task-banner/server/service/task"
	"github.com/xhd2015/task-banner/server/service/task/local_impl"
)

var service task.ITaskStorage = local_impl.New("tasks.json")

type ListTasksRequest struct {
	Mode model.TaskMode `json:"mode"`
}

func ListTasks(ctx context.Context, req *ListTasksRequest) ([]*model.TaskItem, error) {
	return service.LoadTasks(req.Mode)
}
