package local_impl

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"

	"github.com/xhd2015/task-banner/server/model"
	"github.com/xhd2015/task-banner/server/service/task"
)

type LocalStorage struct {
	filename string
	mu       sync.RWMutex
}

var _ task.ITaskStorage = (*LocalStorage)(nil)

func New(filename string) *LocalStorage {
	return &LocalStorage{
		filename: filename,
	}
}

// readTasks reads all tasks from the JSON file
func (s *LocalStorage) readTasks() ([]*model.TaskItem, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	// Ensure directory exists
	dir := filepath.Dir(s.filename)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, err
	}

	data, err := os.ReadFile(s.filename)
	if err != nil {
		if os.IsNotExist(err) {
			return []*model.TaskItem{}, nil
		}
		return nil, err
	}

	var tasks []*model.TaskItem
	if err := json.Unmarshal(data, &tasks); err != nil {
		return nil, err
	}

	return tasks, nil
}

// writeTasks writes all tasks to the JSON file
func (s *LocalStorage) writeTasks(tasks []*model.TaskItem) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	data, err := json.MarshalIndent(tasks, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(s.filename, data, 0644)
}

// SaveTasks saves all tasks to storage
func (s *LocalStorage) SaveTasks(tasks []*model.TaskItem) error {
	return s.writeTasks(tasks)
}

// LoadTasks loads tasks from storage, filtered by mode if specified
func (s *LocalStorage) LoadTasks(mode model.TaskMode) ([]*model.TaskItem, error) {
	allTasks, err := s.readTasks()
	if err != nil {
		return nil, err
	}

	if mode == "" || mode == "shared" {
		return allTasks, nil
	}

	// Filter tasks by mode recursively, including shared tasks
	var filterByMode func([]*model.TaskItem) []*model.TaskItem
	filterByMode = func(tasks []*model.TaskItem) []*model.TaskItem {
		filtered := make([]*model.TaskItem, 0)
		for _, task := range tasks {
			if task.Mode == mode || task.Mode == "" || task.Mode == "shared" {
				taskCopy := *task
				taskCopy.SubTasks = filterByMode(task.SubTasks)
				filtered = append(filtered, &taskCopy)
			}
		}
		return filtered
	}

	return filterByMode(allTasks), nil
}

// findHighestTaskID finds the highest task ID in the tree
func (s *LocalStorage) findHighestTaskID() (int64, error) {
	tasks, err := s.readTasks()
	if err != nil {
		return 0, err
	}

	var maxID int64
	var checkTask func(*model.TaskItem)
	checkTask = func(task *model.TaskItem) {
		if task.ID > maxID {
			maxID = task.ID
		}
		for _, subtask := range task.SubTasks {
			checkTask(subtask)
		}
	}

	for _, task := range tasks {
		checkTask(task)
	}

	return maxID, nil
}

// AddTask adds a new task to storage
func (s *LocalStorage) AddTask(inputTask *model.TaskItem) (*model.TaskItem, error) {
	tasks, err := s.readTasks()
	if err != nil {
		return nil, err
	}

	task := inputTask.ShallowClone()

	// Generate new ID
	highestID, err := s.findHighestTaskID()
	if err != nil {
		return nil, err
	}
	task.ID = highestID + 1

	if task.ParentID != 0 {
		// Add as subtask
		found := false
		var addSubTask func([]*model.TaskItem) []*model.TaskItem
		addSubTask = func(tasks []*model.TaskItem) []*model.TaskItem {
			for i, t := range tasks {
				if t.ID == task.ParentID {
					tasks[i].SubTasks = append([]*model.TaskItem{task}, tasks[i].SubTasks...)
					found = true
					return tasks
				}
				tasks[i].SubTasks = addSubTask(t.SubTasks)
			}
			return tasks
		}
		tasks = addSubTask(tasks)
		if !found {
			return nil, errors.New("parent task not found")
		}
	} else {
		tasks = append([]*model.TaskItem{task}, tasks...)
	}

	err = s.writeTasks(tasks)
	if err != nil {
		return nil, err
	}

	return task, nil
}

// RemoveTask removes a task from storage
func (s *LocalStorage) RemoveTask(taskID int64) error {
	tasks, err := s.readTasks()
	if err != nil {
		return err
	}

	found := false
	var removeTask func([]*model.TaskItem) []*model.TaskItem
	removeTask = func(tasks []*model.TaskItem) []*model.TaskItem {
		filtered := make([]*model.TaskItem, 0)
		for _, task := range tasks {
			if task.ID == taskID {
				found = true
				continue
			}
			task.SubTasks = removeTask(task.SubTasks)
			filtered = append(filtered, task)
		}
		return filtered
	}

	tasks = removeTask(tasks)
	if !found {
		return errors.New("task not found")
	}

	return s.writeTasks(tasks)
}

// UpdateTask updates an existing task in storage
func (s *LocalStorage) UpdateTask(taskID int64, update *model.TaskUpdate) error {
	tasks, err := s.readTasks()
	if err != nil {
		return err
	}

	found := false
	var updateTaskRecursive func([]*model.TaskItem) []*model.TaskItem
	updateTaskRecursive = func(tasks []*model.TaskItem) []*model.TaskItem {
		for i, task := range tasks {
			if task.ID == taskID {
				if update.Title != nil {
					tasks[i].Title = *update.Title
				}
				if update.Status != nil {
					tasks[i].Status = model.TaskStatus(*update.Status)
				}
				if update.Notes != nil {
					tasks[i].Notes = append(tasks[i].Notes, *update.Notes)
				}
				if update.Mode != nil {
					tasks[i].Mode = model.TaskMode(*update.Mode)
				}
				found = true
				return tasks
			}
			tasks[i].SubTasks = updateTaskRecursive(task.SubTasks)
		}
		return tasks
	}

	tasks = updateTaskRecursive(tasks)
	if !found {
		return errors.New("task not found")
	}

	return s.writeTasks(tasks)
}

// ExchangeOrder swaps the order of two tasks at the same level
func (s *LocalStorage) ExchangeOrder(taskID int64, exchangeTaskID int64) error {
	if taskID == 0 {
		return errors.New("requires taskID")
	}
	if exchangeTaskID == 0 {
		return errors.New("requires exchangeTaskID")
	}
	if taskID == exchangeTaskID {
		return nil
	}

	tasks, err := s.readTasks()
	if err != nil {
		return err
	}

	found := false
	var exchangeTasksRecursive func([]*model.TaskItem) []*model.TaskItem
	exchangeTasksRecursive = func(tasks []*model.TaskItem) []*model.TaskItem {
		// Find both tasks at current level
		var aIndex, bIndex = -1, -1
		for i, task := range tasks {
			if task.ID == taskID {
				aIndex = i
			}
			if task.ID == exchangeTaskID {
				bIndex = i
			}
		}

		// If both found at this level, swap them
		if aIndex != -1 && bIndex != -1 {
			tasks[aIndex], tasks[bIndex] = tasks[bIndex], tasks[aIndex]
			found = true
			return tasks
		}

		// Otherwise, search in subtasks
		for i := range tasks {
			tasks[i].SubTasks = exchangeTasksRecursive(tasks[i].SubTasks)
		}
		return tasks
	}

	tasks = exchangeTasksRecursive(tasks)
	if !found {
		return errors.New("tasks not found or not at same level")
	}

	return s.writeTasks(tasks)
}

// AddTaskNote adds a note to a task
func (s *LocalStorage) AddTaskNote(taskID int64, note string) error {
	tasks, err := s.readTasks()
	if err != nil {
		return err
	}

	found := false
	var addNoteRecursive func([]*model.TaskItem) []*model.TaskItem
	addNoteRecursive = func(tasks []*model.TaskItem) []*model.TaskItem {
		for i, task := range tasks {
			if task.ID == taskID {
				tasks[i].Notes = append(tasks[i].Notes, note)
				found = true
				return tasks
			}
			tasks[i].SubTasks = addNoteRecursive(task.SubTasks)
		}
		return tasks
	}

	tasks = addNoteRecursive(tasks)
	if !found {
		return errors.New("task not found")
	}

	return s.writeTasks(tasks)
}

// UpdateTaskNote updates a specific note in a task
func (s *LocalStorage) UpdateTaskNote(taskID int64, noteIndex int, newText string) error {
	tasks, err := s.readTasks()
	if err != nil {
		return err
	}

	found := false
	var updateNoteRecursive func([]*model.TaskItem) []*model.TaskItem
	updateNoteRecursive = func(tasks []*model.TaskItem) []*model.TaskItem {
		for i, task := range tasks {
			if task.ID == taskID {
				if noteIndex >= len(tasks[i].Notes) {
					return tasks
				}
				tasks[i].Notes[noteIndex] = newText
				found = true
				return tasks
			}
			tasks[i].SubTasks = updateNoteRecursive(task.SubTasks)
		}
		return tasks
	}

	tasks = updateNoteRecursive(tasks)
	if !found {
		return errors.New("task not found")
	}

	return s.writeTasks(tasks)
}
