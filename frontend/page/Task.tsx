import { useCallback, useEffect, useState } from "react"
import { Task, createTask, deleteTask, getTasks, updateTask } from "../api/task"
import { Button, Checkbox, Input, List, Modal, Space, message, FloatButton } from "antd"
import { DeleteOutlined, EditOutlined, PlusOutlined } from "@ant-design/icons"

export function Task() {
    const [tasks, setTasks] = useState<Task[]>([])
    const [loading, setLoading] = useState(false)
    const [error, setError] = useState<string | null>(null)
    const [isModalVisible, setIsModalVisible] = useState(false)
    const [editingTask, setEditingTask] = useState<Task | null>(null)
    const [newTaskTitle, setNewTaskTitle] = useState("")

    const loadTasks = async () => {
        try {
            setLoading(true)
            setError(null)
            const fetchedTasks = await getTasks()
            setTasks(fetchedTasks)
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to load tasks')
            message.error('Failed to load tasks')
        } finally {
            setLoading(false)
        }
    }

    useEffect(() => {
        loadTasks()
    }, [])

    useEffect(() => {
        const handleKeyPress = (e: KeyboardEvent) => {
            if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
                e.preventDefault()
                setIsModalVisible(true)
            }
        }

        window.addEventListener('keydown', handleKeyPress)
        return () => window.removeEventListener('keydown', handleKeyPress)
    }, [])

    const handleCreateTask = async () => {
        if (!newTaskTitle.trim()) {
            message.warning('Please enter a task title')
            return
        }

        try {
            const newTask = await createTask({
                title: newTaskTitle,
                status: 'created',
                startTime: new Date().toISOString(),
            })
            setTasks(prev => [...prev, newTask])
            setNewTaskTitle("")
            setIsModalVisible(false)
            message.success('Task created successfully')
        } catch (err) {
            message.error('Failed to create task')
        }
    }
    //aaa
    const handleUpdateTask = async (task: Task) => {
        try {
            await updateTask(task)
            setTasks(prev => prev.map(t => t.id === task.id ? task : t))
            setEditingTask(null)
            message.success('Task updated successfully')
        } catch (err) {
            message.error('Failed to update task')
        }
    }

    const handleDeleteTask = async (taskId: string) => {
        try {
            await deleteTask(taskId)
            setTasks(prev => prev.filter(t => t.id !== taskId))
            message.success('Task deleted successfully')
        } catch (err) {
            message.error('Failed to delete task')
        }
    }

    const handleToggleStatus = async (task: Task) => {
        try {
            const updatedTask: Task = {
                ...task,
                status: task.status === 'done' ? 'created' : 'done'
            }
            await updateTask(updatedTask)
            setTasks(prev => prev.map(t => t.id === task.id ? updatedTask : t))
        } catch (err) {
            message.error('Failed to update task status')
        }
    }

    const renderTaskItem = (task: Task) => (
        <List.Item
            key={task.id}
            actions={[
                <Button
                    icon={<EditOutlined />}
                    onClick={() => setEditingTask(task)}
                    type="text"
                />,
                <Button
                    icon={<DeleteOutlined />}
                    onClick={() => handleDeleteTask(task.id)}
                    type="text"
                    danger
                />
            ]}
        >
            <Space>
                <Checkbox
                    checked={task.status === 'done'}
                    onChange={() => handleToggleStatus(task)}
                />
                <span style={{ textDecoration: task.status === 'done' ? 'line-through' : 'none' }}>
                    {task.title}
                </span>
            </Space>
        </List.Item>
    )

    return (
        <div style={{ padding: '24px' }}>
            <Space direction="vertical" style={{ width: '100%' }} size="large">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <h1>Tasks</h1>
                    <Button
                        type="primary"
                        icon={<PlusOutlined />}
                        onClick={() => setIsModalVisible(true)}
                    >
                        Add Task
                    </Button>
                </div>

                {error && (
                    <div style={{ color: 'red' }}>
                        {error}
                    </div>
                )}

                <List
                    loading={loading}
                    dataSource={tasks || []}
                    renderItem={renderTaskItem}
                    bordered
                />

                <Modal
                    title="Add New Task"
                    open={isModalVisible}
                    onOk={handleCreateTask}
                    onCancel={() => {
                        setIsModalVisible(false)
                        setNewTaskTitle("")
                    }}
                    okButtonProps={{ disabled: !newTaskTitle.trim() }}
                >
                    <Input
                        placeholder="Enter task title"
                        value={newTaskTitle}
                        onChange={e => setNewTaskTitle(e.target.value)}
                        onPressEnter={handleCreateTask}
                        autoFocus
                    />
                    <div style={{ marginTop: 8, color: 'gray', fontSize: '12px' }}>
                        Press Enter to add or Esc to cancel
                    </div>
                </Modal>

                <Modal
                    title="Edit Task"
                    open={!!editingTask}
                    onOk={() => editingTask && handleUpdateTask(editingTask)}
                    onCancel={() => setEditingTask(null)}
                    okButtonProps={{ disabled: !editingTask?.title.trim() }}
                >
                    {editingTask && (
                        <Input
                            value={editingTask.title}
                            onChange={e => setEditingTask({ ...editingTask, title: e.target.value })}
                            onPressEnter={() => editingTask && handleUpdateTask(editingTask)}
                            autoFocus
                        />
                    )}
                </Modal>

                <FloatButton
                    icon={<PlusOutlined />}
                    type="primary"
                    tooltip="Add Task (Ctrl/Cmd + N)"
                    onClick={() => setIsModalVisible(true)}
                    style={{ right: 24, bottom: 24 }}
                />
            </Space>
        </div>
    )
}

