CREATE DATABASE omnisync;
USE omnisync;
-- ==========================================
-- 1. USERS
-- ==========================================
CREATE TABLE users (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- 2. WORKSPACES
-- ==========================================
CREATE TABLE workspaces (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    owner_id CHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ==========================================
-- 3. WORKSPACE MEMBERS (Many-to-Many)
-- ==========================================
-- Links users to workspaces and handles Admin/Member permissions
CREATE TABLE workspace_members (
    workspace_id CHAR(36),
    user_id CHAR(36),
    role ENUM('admin', 'member') DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (workspace_id, user_id),
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ==========================================
-- 4. PROJECTS
-- ==========================================
CREATE TABLE projects (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    workspace_id CHAR(36),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
);

-- ==========================================
-- 5. TASKS
-- ==========================================
CREATE TABLE tasks (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    project_id CHAR(36),
    assigned_to CHAR(36),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status ENUM('todo', 'in_progress', 'review', 'done') DEFAULT 'todo',
    priority ENUM('low', 'medium', 'high') DEFAULT 'medium',
    due_date DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL
);

-- ==========================================
-- 6. EVENTS
-- ==========================================
CREATE TABLE events (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    workspace_id CHAR(36),
    created_by CHAR(36),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

-- ==========================================
-- 7. EVENT RSVPs (Many-to-Many)
-- ==========================================
CREATE TABLE event_rsvps (
    event_id CHAR(36),
    user_id CHAR(36),
    rsvp_status ENUM('going', 'maybe', 'declined', 'pending') DEFAULT 'pending',
    PRIMARY KEY (event_id, user_id),
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ==========================================
-- 8. INDEXES (For Query Optimization)
-- ==========================================
-- Speeds up finding all workspaces a user belongs to
CREATE INDEX idx_workspace_members_user ON workspace_members(user_id);

-- Speeds up loading all projects inside a specific workspace
CREATE INDEX idx_projects_workspace ON projects(workspace_id);

-- Speeds up loading the Kanban board (all tasks in a project)
CREATE INDEX idx_tasks_project ON tasks(project_id);

-- Speeds up the "My Tasks" dashboard (finding tasks assigned to one user)
CREATE INDEX idx_tasks_assigned_to ON tasks(assigned_to);

-- Speeds up fetching the calendar events for a workspace
CREATE INDEX idx_events_workspace ON events(workspace_id);


-- ==========================================
-- 9. SEED DATA (For Development & Testing)
-- ==========================================

-- 1. Create two test users (You and Muhsin)
INSERT INTO users (id, full_name, email, password_hash) VALUES 
('11111111-1111-1111-1111-111111111111', 'Abdirahman Ahmed', 'abdi@test.com', 'hashedpassword123'),
('22222222-2222-2222-2222-222222222222', 'Muhsin Ahmed', 'muhsin@test.com', 'hashedpassword123');

-- 2. Create a test Workspace
INSERT INTO workspaces (id, name, description, owner_id) VALUES 
('33333333-3333-3333-3333-333333333333', 'OmniSync HQ', 'Main development workspace', '11111111-1111-1111-1111-111111111111');

-- 3. Add both users to the Workspace
INSERT INTO workspace_members (workspace_id, user_id, role) VALUES 
('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'admin'),
('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'member');

-- 4. Create a test Project
INSERT INTO projects (id, workspace_id, name, description) VALUES 
('44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', 'Week 1 Sprint', 'Initial setup tasks');

-- 5. Create some test Tasks for the Kanban board
INSERT INTO tasks (id, project_id, assigned_to, title, description, status, priority) VALUES 
('55555555-5555-5555-5555-555555555555', '44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Design SQL Schema', 'Write all CREATE TABLE scripts', 'done', 'high'),
('66666666-6666-6666-6666-666666666666', '44444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', 'Build Kanban UI', 'Create Flutter drag-and-drop board', 'in_progress', 'high');