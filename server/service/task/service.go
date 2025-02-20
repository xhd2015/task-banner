package task

import "github.com/xhd2015/task-banner/server/model"

type ITaskStorage interface {
	SaveTasks(tasks []*model.TaskItem) error
	LoadTasks(mode model.TaskMode) ([]*model.TaskItem, error)
	AddTask(task *model.TaskItem) error
	RemoveTask(taskId int64) error
	UpdateTask(taskId int64, update *model.TaskUpdate) error
	ExchangeOrder(aID int64, bID int64) error
	AddTaskNote(taskId int64, note string) error
	UpdateTaskNote(taskId int64, noteIndex int, newText string) error
}
