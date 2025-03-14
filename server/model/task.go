package model

import "time"

type TaskMode string

const (
	TaskModeWork TaskMode = "work"
	TaskModeLife TaskMode = "life"
)

type TaskStatus string

const (
	TaskStatusCreated  TaskStatus = "created"
	TaskStatusDone     TaskStatus = "done"
	TaskStatusArchived TaskStatus = "archived"
)

type SwiftTimestamp float64

type TaskItem struct {
	ID        int64          `json:"id"`
	Title     string         `json:"title"`
	StartTime SwiftTimestamp `json:"startTime"`
	ParentID  int64          `json:"parentID"`
	SubTasks  []*TaskItem    `json:"subTasks"`
	Mode      TaskMode       `json:"mode"`
	Status    TaskStatus     `json:"status"`
	Notes     []string       `json:"notes"`
}

type TaskUpdate struct {
	Title  *string `json:"title"`
	Status *string `json:"status"`
	Notes  *string `json:"notes"`
	Mode   *string `json:"mode"`
}

// ConvertSwiftTimestamp converts a Swift timestamp (seconds since January 1, 2001) to a Go time.Time
func ConvertSwiftTimestamp(swiftTimestamp SwiftTimestamp) time.Time {
	// Swift's reference date: January 1, 2001 at 00:00:00 UTC
	swiftReferenceDate := time.Date(2001, 1, 1, 0, 0, 0, 0, time.UTC)
	// Add the seconds to the reference date
	goTime := swiftReferenceDate.Add(time.Duration(float64(swiftTimestamp) * float64(time.Second)))
	return goTime
}

func (c *TaskItem) ShallowClone() *TaskItem {
	if c == nil {
		return nil
	}
	cl := *c
	return &cl
}
