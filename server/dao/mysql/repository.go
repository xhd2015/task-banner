package mysql

import (
	"database/sql"
	"encoding/json"
	"errors"
	"sync"

	"github.com/xhd2015/task-banner/server/dao"
)

type Repository struct {
	db *sql.DB
	mu sync.RWMutex
}

func New(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) InitSchema() error {
	schema := `
	CREATE TABLE IF NOT EXISTS tasks (
		id BIGINT PRIMARY KEY AUTO_INCREMENT,
		title VARCHAR(255) NOT NULL,
		status VARCHAR(50) NOT NULL,
		start_time DATETIME NOT NULL,
		parent_id BIGINT,
		sub_tasks JSON,
		FOREIGN KEY (parent_id) REFERENCES tasks(id) ON DELETE CASCADE
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
	`

	_, err := r.db.Exec(schema)
	return err
}

func (r *Repository) GetTasks() ([]dao.Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	rows, err := r.db.Query("SELECT id, title, status, start_time, parent_id, sub_tasks FROM tasks WHERE parent_id IS NULL")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tasks []dao.Task
	for rows.Next() {
		var task dao.Task
		var subTasksJSON sql.NullString
		var parentID sql.NullInt64

		err := rows.Scan(&task.ID, &task.Title, &task.Status, &task.StartTime, &parentID, &subTasksJSON)
		if err != nil {
			return nil, err
		}

		if parentID.Valid {
			task.ParentID = &parentID.Int64
		}

		if subTasksJSON.Valid {
			err = json.Unmarshal([]byte(subTasksJSON.String), &task.SubTasks)
			if err != nil {
				return nil, err
			}
		}

		tasks = append(tasks, task)
	}

	return tasks, nil
}

func (r *Repository) GetTaskByID(id int64) (*dao.Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var task dao.Task
	var subTasksJSON sql.NullString
	var parentID sql.NullInt64

	err := r.db.QueryRow(
		"SELECT id, title, status, start_time, parent_id, sub_tasks FROM tasks WHERE id = ?",
		id,
	).Scan(&task.ID, &task.Title, &task.Status, &task.StartTime, &parentID, &subTasksJSON)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	if parentID.Valid {
		task.ParentID = &parentID.Int64
	}

	if subTasksJSON.Valid {
		err = json.Unmarshal([]byte(subTasksJSON.String), &task.SubTasks)
		if err != nil {
			return nil, err
		}
	}

	return &task, nil
}

func (r *Repository) CreateTask(task *dao.Task) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	subTasksJSON, err := json.Marshal(task.SubTasks)
	if err != nil {
		return err
	}

	result, err := r.db.Exec(
		"INSERT INTO tasks (title, status, start_time, parent_id, sub_tasks) VALUES (?, ?, ?, ?, ?)",
		task.Title, task.Status, task.StartTime, task.ParentID, string(subTasksJSON),
	)
	if err != nil {
		return err
	}

	id, err := result.LastInsertId()
	if err != nil {
		return err
	}
	task.ID = id

	return nil
}

func (r *Repository) UpdateTask(task *dao.Task) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	subTasksJSON, err := json.Marshal(task.SubTasks)
	if err != nil {
		return err
	}

	result, err := r.db.Exec(
		"UPDATE tasks SET title = ?, status = ?, start_time = ?, parent_id = ?, sub_tasks = ? WHERE id = ?",
		task.Title, task.Status, task.StartTime, task.ParentID, string(subTasksJSON), task.ID,
	)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}

	if rowsAffected == 0 {
		return errors.New("task not found")
	}

	return nil
}

func (r *Repository) DeleteTask(id int64) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	result, err := r.db.Exec("DELETE FROM tasks WHERE id = ?", id)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}

	if rowsAffected == 0 {
		return errors.New("task not found")
	}

	return nil
}

func (r *Repository) AddSubTask(parentID int64, task *dao.Task) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	// Start a transaction
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Get the parent task
	var parentTask dao.Task
	var subTasksJSON sql.NullString
	var pID sql.NullInt64

	err = tx.QueryRow(
		"SELECT id, title, status, start_time, parent_id, sub_tasks FROM tasks WHERE id = ?",
		parentID,
	).Scan(&parentTask.ID, &parentTask.Title, &parentTask.Status, &parentTask.StartTime, &pID, &subTasksJSON)

	if err == sql.ErrNoRows {
		return errors.New("parent task not found")
	}
	if err != nil {
		return err
	}

	if subTasksJSON.Valid {
		err = json.Unmarshal([]byte(subTasksJSON.String), &parentTask.SubTasks)
		if err != nil {
			return err
		}
	}

	// Set the parent ID for the new subtask
	task.ParentID = &parentID

	// Add the task to the tasks table
	subTasksJSON2, err := json.Marshal(task.SubTasks)
	if err != nil {
		return err
	}

	result, err := tx.Exec(
		"INSERT INTO tasks (title, status, start_time, parent_id, sub_tasks) VALUES (?, ?, ?, ?, ?)",
		task.Title, task.Status, task.StartTime, task.ParentID, string(subTasksJSON2),
	)
	if err != nil {
		return err
	}

	// Get the new task ID
	id, err := result.LastInsertId()
	if err != nil {
		return err
	}
	task.ID = id

	// Update parent's subtasks
	parentTask.SubTasks = append(parentTask.SubTasks, *task)
	updatedSubTasksJSON, err := json.Marshal(parentTask.SubTasks)
	if err != nil {
		return err
	}

	_, err = tx.Exec(
		"UPDATE tasks SET sub_tasks = ? WHERE id = ?",
		string(updatedSubTasksJSON), parentID,
	)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func (r *Repository) Close() error {
	return r.db.Close()
}
