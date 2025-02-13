package json

import (
	"encoding/json"
	"errors"
	"os"
	"sync"

	"github.com/xhd2015/task-banner/server/dao"
)

type Repository struct {
	filename string
	mu       sync.RWMutex
}

func New(filename string) *Repository {
	return &Repository{
		filename: filename,
	}
}

func (r *Repository) readTasks() ([]dao.Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	data, err := os.ReadFile(r.filename)
	if err != nil {
		if os.IsNotExist(err) {
			return []dao.Task{}, nil
		}
		return nil, err
	}

	var tasks []dao.Task
	if err := json.Unmarshal(data, &tasks); err != nil {
		return nil, err
	}

	return tasks, nil
}

func (r *Repository) writeTasks(tasks []dao.Task) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	data, err := json.MarshalIndent(tasks, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(r.filename, data, 0644)
}

func (r *Repository) GetTasks() ([]dao.Task, error) {
	return r.readTasks()
}

func (r *Repository) GetTaskByID(id int64) (*dao.Task, error) {
	tasks, err := r.readTasks()
	if err != nil {
		return nil, err
	}

	var findTask func(tasks []dao.Task, id int64) *dao.Task
	findTask = func(tasks []dao.Task, id int64) *dao.Task {
		for i := range tasks {
			if tasks[i].ID == id {
				return &tasks[i]
			}
			if len(tasks[i].SubTasks) > 0 {
				if found := findTask(tasks[i].SubTasks, id); found != nil {
					return found
				}
			}
		}
		return nil
	}

	task := findTask(tasks, id)
	if task == nil {
		return nil, nil
	}
	return task, nil
}

func (r *Repository) CreateTask(task *dao.Task) error {
	tasks, err := r.readTasks()
	if err != nil {
		return err
	}

	// Generate new ID
	var maxID int64
	for _, t := range tasks {
		if t.ID > maxID {
			maxID = t.ID
		}
	}
	task.ID = maxID + 1

	tasks = append(tasks, *task)
	return r.writeTasks(tasks)
}

func (r *Repository) UpdateTask(task *dao.Task) error {
	tasks, err := r.readTasks()
	if err != nil {
		return err
	}

	var updateTask func(tasks []dao.Task, task *dao.Task) ([]dao.Task, bool)
	updateTask = func(tasks []dao.Task, task *dao.Task) ([]dao.Task, bool) {
		for i := range tasks {
			if tasks[i].ID == task.ID {
				tasks[i] = *task
				return tasks, true
			}
			if len(tasks[i].SubTasks) > 0 {
				updatedSubTasks, found := updateTask(tasks[i].SubTasks, task)
				if found {
					tasks[i].SubTasks = updatedSubTasks
					return tasks, true
				}
			}
		}
		return tasks, false
	}

	updatedTasks, found := updateTask(tasks, task)
	if !found {
		return errors.New("task not found")
	}

	return r.writeTasks(updatedTasks)
}

func (r *Repository) DeleteTask(id int64) error {
	tasks, err := r.readTasks()
	if err != nil {
		return err
	}

	var deleteTask func(tasks []dao.Task, id int64) ([]dao.Task, bool)
	deleteTask = func(tasks []dao.Task, id int64) ([]dao.Task, bool) {
		for i := range tasks {
			if tasks[i].ID == id {
				return append(tasks[:i], tasks[i+1:]...), true
			}
			if len(tasks[i].SubTasks) > 0 {
				updatedSubTasks, found := deleteTask(tasks[i].SubTasks, id)
				if found {
					tasks[i].SubTasks = updatedSubTasks
					return tasks, true
				}
			}
		}
		return tasks, false
	}

	updatedTasks, found := deleteTask(tasks, id)
	if !found {
		return errors.New("task not found")
	}

	return r.writeTasks(updatedTasks)
}

func (r *Repository) AddSubTask(parentID int64, task *dao.Task) error {
	tasks, err := r.readTasks()
	if err != nil {
		return err
	}

	// Generate new ID
	var maxID int64
	for _, t := range tasks {
		if t.ID > maxID {
			maxID = t.ID
		}
		for _, st := range t.SubTasks {
			if st.ID > maxID {
				maxID = st.ID
			}
		}
	}
	task.ID = maxID + 1

	var addSubTask func(tasks []dao.Task, parentID int64, task *dao.Task) ([]dao.Task, bool)
	addSubTask = func(tasks []dao.Task, parentID int64, task *dao.Task) ([]dao.Task, bool) {
		for i := range tasks {
			if tasks[i].ID == parentID {
				tasks[i].SubTasks = append(tasks[i].SubTasks, *task)
				return tasks, true
			}
			if len(tasks[i].SubTasks) > 0 {
				updatedSubTasks, found := addSubTask(tasks[i].SubTasks, parentID, task)
				if found {
					tasks[i].SubTasks = updatedSubTasks
					return tasks, true
				}
			}
		}
		return tasks, false
	}

	updatedTasks, found := addSubTask(tasks, parentID, task)
	if !found {
		return errors.New("parent task not found")
	}

	return r.writeTasks(updatedTasks)
}
