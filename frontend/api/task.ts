export interface Task {
    id: number;
    title: string;
    status: 'created' | 'done';
    startTime: string;
    parentId?: number;
    subTasks?: Task[];
}

export async function getTasks(): Promise<Task[]> {
    const response = await fetch('/tasks');
    if (!response.ok) {
        throw new Error(`Failed to fetch tasks: ${response.statusText}`);
    }
    return response.json();
}

export async function getTask(id: number): Promise<Task> {
    const response = await fetch(`/task?id=${id}`);
    if (!response.ok) {
        throw new Error(`Failed to fetch task: ${response.statusText}`);
    }
    return response.json();
}

export async function createTask(task: Omit<Task, 'id'>): Promise<Task> {
    const response = await fetch('/tasks', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(task),
    });
    if (!response.ok) {
        throw new Error(`Failed to create task: ${response.statusText}`);
    }
    return response.json();
}

export async function updateTask(task: Task): Promise<Task> {
    const response = await fetch('/tasks', {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(task),
    });
    if (!response.ok) {
        throw new Error(`Failed to update task: ${response.statusText}`);
    }
    return response.json();
}

export async function deleteTask(id: number): Promise<void> {
    const response = await fetch(`/tasks?id=${id}`, {
        method: 'DELETE',
    });
    if (!response.ok) {
        throw new Error(`Failed to delete task: ${response.statusText}`);
    }
}

export async function addSubTask(parentId: number, task: Omit<Task, 'id'>): Promise<Task> {
    const response = await fetch(`/subtask?parentId=${parentId}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(task),
    });
    if (!response.ok) {
        throw new Error(`Failed to add subtask: ${response.statusText}`);
    }
    return response.json();
} 