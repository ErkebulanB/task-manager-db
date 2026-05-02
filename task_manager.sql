DROP EVENT TRIGGER IF EXISTS trg_task_manager_ddl_log;
DROP SCHEMA IF EXISTS task_manager CASCADE;

CREATE SCHEMA task_manager;
SET search_path TO task_manager;

CREATE TABLE app_roles (
    role_id SMALLSERIAL PRIMARY KEY,
    role_name VARCHAR(30) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_role_name CHECK (role_name IN ('admin', 'manager', 'member', 'viewer'))
);

CREATE TABLE app_users (
    user_id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role_id SMALLINT NOT NULL REFERENCES app_roles(role_id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_username_length CHECK (LENGTH(username) >= 3),
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE TABLE projects (
    project_id BIGSERIAL PRIMARY KEY,
    project_name VARCHAR(100) NOT NULL,
    description TEXT,
    owner_id BIGINT REFERENCES app_users(user_id) ON DELETE SET NULL,
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_project_name_owner UNIQUE (project_name, owner_id),
    CONSTRAINT chk_project_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE task_statuses (
    status_id SMALLSERIAL PRIMARY KEY,
    status_name VARCHAR(30) NOT NULL UNIQUE,
    CONSTRAINT chk_status_name CHECK (status_name IN ('todo', 'in_progress', 'done', 'cancelled'))
);

CREATE TABLE priorities (
    priority_id SMALLSERIAL PRIMARY KEY,
    priority_name VARCHAR(30) NOT NULL UNIQUE,
    priority_weight INT NOT NULL,
    CONSTRAINT chk_priority_name CHECK (priority_name IN ('low', 'medium', 'high', 'urgent')),
    CONSTRAINT chk_priority_weight CHECK (priority_weight BETWEEN 1 AND 4)
);

CREATE TABLE categories (
    category_id BIGSERIAL PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE tasks (
    task_id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    created_by BIGINT NOT NULL REFERENCES app_users(user_id),
    assigned_to BIGINT REFERENCES app_users(user_id) ON DELETE SET NULL,
    status_id SMALLINT NOT NULL REFERENCES task_statuses(status_id),
    priority_id SMALLINT NOT NULL REFERENCES priorities(priority_id),
    title VARCHAR(150) NOT NULL,
    description TEXT,
    due_date DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    CONSTRAINT chk_task_title_length CHECK (LENGTH(title) >= 3),
    CONSTRAINT chk_due_date CHECK (due_date IS NULL OR due_date >= created_at::DATE),
    CONSTRAINT chk_completed_date CHECK (completed_at IS NULL OR completed_at >= created_at)
);

CREATE TABLE task_categories (
    task_id BIGINT NOT NULL REFERENCES tasks(task_id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES categories(category_id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, category_id)
);

CREATE TABLE comments (
    comment_id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL REFERENCES tasks(task_id) ON DELETE CASCADE,
    author_id BIGINT NOT NULL REFERENCES app_users(user_id),
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_comment_length CHECK (LENGTH(comment_text) >= 2)
);

CREATE TABLE task_status_history (
    history_id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL REFERENCES tasks(task_id) ON DELETE CASCADE,
    old_status_id SMALLINT REFERENCES task_statuses(status_id),
    new_status_id SMALLINT NOT NULL REFERENCES task_statuses(status_id),
    changed_by TEXT NOT NULL DEFAULT CURRENT_USER,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE task_audit_logs (
    audit_id BIGSERIAL PRIMARY KEY,
    task_id BIGINT,
    action_type VARCHAR(10) NOT NULL,
    old_data JSONB,
    new_data JSONB,
    changed_by TEXT NOT NULL DEFAULT CURRENT_USER,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE statement_logs (
    statement_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    action_type VARCHAR(20) NOT NULL,
    executed_by TEXT NOT NULL DEFAULT CURRENT_USER,
    executed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ddl_logs (
    ddl_log_id BIGSERIAL PRIMARY KEY,
    event_type TEXT,
    command_tag TEXT,
    object_type TEXT,
    object_identity TEXT,
    executed_by TEXT NOT NULL DEFAULT CURRENT_USER,
    executed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_role_id ON app_users(role_id);
CREATE INDEX idx_projects_owner_id ON projects(owner_id);
CREATE INDEX idx_tasks_project_id ON tasks(project_id);
CREATE INDEX idx_tasks_assigned_to ON tasks(assigned_to);
CREATE INDEX idx_tasks_status_id ON tasks(status_id);
CREATE INDEX idx_tasks_priority_id ON tasks(priority_id);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
CREATE INDEX idx_task_categories_category_id ON task_categories(category_id);
CREATE INDEX idx_comments_task_id ON comments(task_id);
CREATE INDEX idx_comments_author_id ON comments(author_id);

INSERT INTO app_roles (role_name)
VALUES
    ('admin'),
    ('manager'),
    ('member'),
    ('viewer');

INSERT INTO task_statuses (status_name)
VALUES
    ('todo'),
    ('in_progress'),
    ('done'),
    ('cancelled');

INSERT INTO priorities (priority_name, priority_weight)
VALUES
    ('low', 1),
    ('medium', 2),
    ('high', 3),
    ('urgent', 4);

INSERT INTO app_users (username, email, password_hash, role_id)
VALUES
    ('admin_user', 'admin@example.com', 'hash_admin_123', 1),
    ('manager_user', 'manager@example.com', 'hash_manager_123', 2),
    ('member_user', 'member@example.com', 'hash_member_123', 3),
    ('viewer_user', 'viewer@example.com', 'hash_viewer_123', 4);

INSERT INTO projects (project_name, description, owner_id, start_date, end_date)
VALUES
    ('University Tasks', 'Университет тапсырмаларын басқару жүйесі', 2, CURRENT_DATE, CURRENT_DATE + 90),
    ('Personal Development', 'Жеке даму және оқу жоспары', 3, CURRENT_DATE, CURRENT_DATE + 180);

INSERT INTO categories (category_name, description)
VALUES
    ('Database', 'Database және SQL тапсырмалары'),
    ('Programming', 'Бағдарламалау тапсырмалары'),
    ('Design', 'UI/UX және дизайн тапсырмалары'),
    ('Report', 'Есеп жазу және құжаттау');

INSERT INTO tasks (
    project_id,
    created_by,
    assigned_to,
    status_id,
    priority_id,
    title,
    description,
    due_date
)
VALUES
    (1, 2, 3, 1, 3, 'Prepare SRS 2 database', 'СРС №2 үшін деректер қорын дайындау', CURRENT_DATE + 5),
    (1, 2, 3, 2, 4, 'Write SQL procedures', 'Stored procedure жазу және тестілеу', CURRENT_DATE + 7),
    (1, 2, 3, 1, 2, 'Draw ER diagram', 'ER диаграмманы жаңарту', CURRENT_DATE + 3),
    (2, 3, 3, 1, 2, 'Learn normalization', '1NF, 2NF, 3NF, BCNF қайталау', CURRENT_DATE + 10);

INSERT INTO task_categories (task_id, category_id)
VALUES
    (1, 1),
    (1, 4),
    (2, 1),
    (2, 2),
    (3, 3),
    (4, 1);

INSERT INTO comments (task_id, author_id, comment_text)
VALUES
    (1, 2, 'Бұл тапсырманы бірінші орындау керек.'),
    (2, 3, 'Процедуралар үшін 3-4 мысал жеткілікті.'),
    (3, 2, 'ER диаграммаға нормализациядан кейінгі кестелерді қосу керек.');

CREATE OR REPLACE PROCEDURE sp_create_task(
    p_project_id BIGINT,
    p_created_by BIGINT,
    p_assigned_to BIGINT,
    p_title VARCHAR,
    p_description TEXT,
    p_priority_name VARCHAR,
    p_due_date DATE
)
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
DECLARE
    v_status_id SMALLINT;
    v_priority_id SMALLINT;
BEGIN
    SELECT status_id INTO v_status_id
    FROM task_statuses
    WHERE status_name = 'todo';

    SELECT priority_id INTO v_priority_id
    FROM priorities
    WHERE priority_name = p_priority_name;

    IF v_priority_id IS NULL THEN
        RAISE EXCEPTION 'Priority "%" табылмады', p_priority_name;
    END IF;

    INSERT INTO tasks (
        project_id,
        created_by,
        assigned_to,
        status_id,
        priority_id,
        title,
        description,
        due_date
    )
    VALUES (
        p_project_id,
        p_created_by,
        p_assigned_to,
        v_status_id,
        v_priority_id,
        p_title,
        p_description,
        p_due_date
    );
END;
$$;

CREATE OR REPLACE PROCEDURE sp_change_task_status(
    p_task_id BIGINT,
    p_status_name VARCHAR
)
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
DECLARE
    v_status_id SMALLINT;
BEGIN
    SELECT status_id INTO v_status_id
    FROM task_statuses
    WHERE status_name = p_status_name;

    IF v_status_id IS NULL THEN
        RAISE EXCEPTION 'Status "%" табылмады', p_status_name;
    END IF;

    UPDATE tasks
    SET
        status_id = v_status_id,
        completed_at = CASE
            WHEN p_status_name = 'done' THEN CURRENT_TIMESTAMP
            ELSE NULL
        END
    WHERE task_id = p_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Task ID % табылмады', p_task_id;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_add_comment(
    p_task_id BIGINT,
    p_author_id BIGINT,
    p_comment_text TEXT
)
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
BEGIN
    INSERT INTO comments (task_id, author_id, comment_text)
    VALUES (p_task_id, p_author_id, p_comment_text);
END;
$$;

CREATE OR REPLACE PROCEDURE sp_assign_category(
    p_task_id BIGINT,
    p_category_name VARCHAR
)
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
DECLARE
    v_category_id BIGINT;
BEGIN
    SELECT category_id INTO v_category_id
    FROM categories
    WHERE category_name = p_category_name;

    IF v_category_id IS NULL THEN
        RAISE EXCEPTION 'Category "%" табылмады', p_category_name;
    END IF;

    INSERT INTO task_categories (task_id, category_id)
    VALUES (p_task_id, v_category_id)
    ON CONFLICT (task_id, category_id) DO NOTHING;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_delete_task(
    p_task_id BIGINT
)
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
BEGIN
    DELETE FROM tasks
    WHERE task_id = p_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Task ID % табылмады', p_task_id;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION fn_user_task_count(
    p_user_id BIGINT
)
RETURNS INT
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM tasks
    WHERE assigned_to = p_user_id;

    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION fn_user_completion_percent(
    p_user_id BIGINT
)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
DECLARE
    v_percent NUMERIC(5,2);
BEGIN
    SELECT COALESCE(
        ROUND(
            COUNT(*) FILTER (WHERE s.status_name = 'done')::NUMERIC
            / NULLIF(COUNT(*), 0) * 100,
            2
        ),
        0
    )
    INTO v_percent
    FROM tasks t
    JOIN task_statuses s ON t.status_id = s.status_id
    WHERE t.assigned_to = p_user_id;

    RETURN v_percent;
END;
$$;

CREATE OR REPLACE FUNCTION fn_overdue_task_count(
    p_user_id BIGINT
)
RETURNS INT
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM tasks t
    JOIN task_statuses s ON t.status_id = s.status_id
    WHERE t.assigned_to = p_user_id
      AND t.due_date < CURRENT_DATE
      AND s.status_name <> 'done';

    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION fn_project_progress(
    p_project_id BIGINT
)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
DECLARE
    v_progress NUMERIC(5,2);
BEGIN
    SELECT COALESCE(
        ROUND(
            COUNT(*) FILTER (WHERE s.status_name = 'done')::NUMERIC
            / NULLIF(COUNT(*), 0) * 100,
            2
        ),
        0
    )
    INTO v_progress
    FROM tasks t
    JOIN task_statuses s ON t.status_id = s.status_id
    WHERE t.project_id = p_project_id;

    RETURN v_progress;
END;
$$;

CREATE OR REPLACE FUNCTION fn_tasks_by_status(
    p_status_name VARCHAR
)
RETURNS TABLE (
    task_id BIGINT,
    title VARCHAR,
    project_name VARCHAR,
    assigned_user VARCHAR,
    priority_name VARCHAR,
    due_date DATE
)
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.task_id,
        t.title::VARCHAR,
        p.project_name::VARCHAR,
        u.username::VARCHAR,
        pr.priority_name::VARCHAR,
        t.due_date
    FROM tasks t
    JOIN projects p ON t.project_id = p.project_id
    LEFT JOIN app_users u ON t.assigned_to = u.user_id
    JOIN priorities pr ON t.priority_id = pr.priority_id
    JOIN task_statuses s ON t.status_id = s.status_id
    WHERE s.status_name = p_status_name
    ORDER BY t.due_date;
END;
$$;

CREATE OR REPLACE FUNCTION trg_fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION trg_fn_task_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO task_audit_logs (task_id, action_type, old_data, new_data)
        VALUES (NEW.task_id, TG_OP, NULL, TO_JSONB(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO task_audit_logs (task_id, action_type, old_data, new_data)
        VALUES (NEW.task_id, TG_OP, TO_JSONB(OLD), TO_JSONB(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO task_audit_logs (task_id, action_type, old_data, new_data)
        VALUES (OLD.task_id, TG_OP, TO_JSONB(OLD), NULL);
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trg_fn_statement_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
BEGIN
    INSERT INTO statement_logs (table_name, action_type)
    VALUES (TG_TABLE_NAME, TG_OP);

    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trg_fn_status_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
BEGIN
    IF OLD.status_id IS DISTINCT FROM NEW.status_id THEN
        INSERT INTO task_status_history (
            task_id,
            old_status_id,
            new_status_id
        )
        VALUES (
            NEW.task_id,
            OLD.status_id,
            NEW.status_id
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tasks_set_updated_at
BEFORE UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION trg_fn_set_updated_at();

CREATE TRIGGER trg_tasks_audit_row
AFTER INSERT OR UPDATE OR DELETE ON tasks
FOR EACH ROW
EXECUTE FUNCTION trg_fn_task_audit();

CREATE TRIGGER trg_tasks_statement_log
AFTER INSERT OR UPDATE OR DELETE ON tasks
FOR EACH STATEMENT
EXECUTE FUNCTION trg_fn_statement_log();

CREATE TRIGGER trg_tasks_status_history
AFTER UPDATE OF status_id ON tasks
FOR EACH ROW
EXECUTE FUNCTION trg_fn_status_history();

CREATE OR REPLACE VIEW active_tasks_view AS
SELECT
    t.task_id,
    t.project_id,
    p.project_name,
    t.created_by,
    t.assigned_to,
    u.username AS assigned_username,
    s.status_name,
    pr.priority_name,
    t.title,
    t.description,
    t.due_date,
    t.created_at,
    t.updated_at
FROM tasks t
JOIN projects p ON t.project_id = p.project_id
LEFT JOIN app_users u ON t.assigned_to = u.user_id
JOIN task_statuses s ON t.status_id = s.status_id
JOIN priorities pr ON t.priority_id = pr.priority_id
WHERE s.status_name IN ('todo', 'in_progress');

CREATE OR REPLACE FUNCTION trg_fn_active_tasks_view_iud()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
DECLARE
    v_status_id SMALLINT;
    v_priority_id SMALLINT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT status_id INTO v_status_id
        FROM task_statuses
        WHERE status_name = COALESCE(NEW.status_name, 'todo');

        SELECT priority_id INTO v_priority_id
        FROM priorities
        WHERE priority_name = COALESCE(NEW.priority_name, 'medium');

        INSERT INTO tasks (
            project_id,
            created_by,
            assigned_to,
            status_id,
            priority_id,
            title,
            description,
            due_date
        )
        VALUES (
            NEW.project_id,
            NEW.created_by,
            NEW.assigned_to,
            v_status_id,
            v_priority_id,
            NEW.title,
            NEW.description,
            NEW.due_date
        )
        RETURNING task_id INTO NEW.task_id;

        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        SELECT status_id INTO v_status_id
        FROM task_statuses
        WHERE status_name = NEW.status_name;

        SELECT priority_id INTO v_priority_id
        FROM priorities
        WHERE priority_name = NEW.priority_name;

        UPDATE tasks
        SET
            project_id = NEW.project_id,
            assigned_to = NEW.assigned_to,
            status_id = v_status_id,
            priority_id = v_priority_id,
            title = NEW.title,
            description = NEW.description,
            due_date = NEW.due_date
        WHERE task_id = OLD.task_id;

        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        DELETE FROM tasks
        WHERE task_id = OLD.task_id;

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_active_tasks_view_iud
INSTEAD OF INSERT OR UPDATE OR DELETE ON active_tasks_view
FOR EACH ROW
EXECUTE FUNCTION trg_fn_active_tasks_view_iud();

CREATE OR REPLACE FUNCTION trg_fn_ddl_log()
RETURNS EVENT_TRIGGER
LANGUAGE plpgsql
SET search_path TO task_manager
AS $$
BEGIN
    INSERT INTO ddl_logs (
        event_type,
        command_tag,
        object_type,
        object_identity
    )
    SELECT
        TG_EVENT,
        command_tag,
        object_type,
        object_identity
    FROM pg_event_trigger_ddl_commands();
END;
$$;

DO $do$
BEGIN
    BEGIN
        EXECUTE $cmd$
            CREATE EVENT TRIGGER trg_task_manager_ddl_log
            ON ddl_command_end
            WHEN TAG IN (
                'CREATE TABLE',
                'ALTER TABLE',
                'DROP TABLE',
                'CREATE INDEX',
                'DROP INDEX',
                'CREATE VIEW',
                'DROP VIEW',
                'CREATE FUNCTION',
                'CREATE PROCEDURE'
            )
            EXECUTE FUNCTION task_manager.trg_fn_ddl_log()
        $cmd$;
    EXCEPTION
        WHEN insufficient_privilege THEN NULL;
        WHEN duplicate_object THEN NULL;
    END;
END;
$do$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tm_admin') THEN
        CREATE ROLE tm_admin LOGIN PASSWORD 'admin123';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tm_manager') THEN
        CREATE ROLE tm_manager LOGIN PASSWORD 'manager123';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tm_member') THEN
        CREATE ROLE tm_member LOGIN PASSWORD 'member123';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tm_viewer') THEN
        CREATE ROLE tm_viewer LOGIN PASSWORD 'viewer123';
    END IF;
END;
$$;

GRANT USAGE ON SCHEMA task_manager TO tm_admin, tm_manager, tm_member, tm_viewer;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA task_manager TO tm_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA task_manager TO tm_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA task_manager TO tm_admin;
GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA task_manager TO tm_admin;

GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA task_manager TO tm_manager;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA task_manager TO tm_manager;

GRANT SELECT ON ALL TABLES IN SCHEMA task_manager TO tm_member;
GRANT INSERT, UPDATE ON task_manager.tasks TO tm_member;
GRANT INSERT ON task_manager.comments TO tm_member;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA task_manager TO tm_member;

GRANT SELECT ON ALL TABLES IN SCHEMA task_manager TO tm_viewer;

CALL task_manager.sp_create_task(
    1,
    2,
    3,
    'Test stored procedure',
    'Бұл тапсырма procedure арқылы қосылды',
    'high',
    CURRENT_DATE + 4
);

CALL task_manager.sp_change_task_status(1, 'in_progress');

CALL task_manager.sp_add_comment(
    1,
    3,
    'Procedure арқылы комментарий қосылды.'
);

CALL task_manager.sp_assign_category(1, 'Programming');

SELECT task_manager.fn_user_task_count(3) AS user_task_count;

SELECT task_manager.fn_user_completion_percent(3) AS completion_percent;

SELECT task_manager.fn_overdue_task_count(3) AS overdue_task_count;

SELECT task_manager.fn_project_progress(1) AS project_progress;

SELECT * FROM task_manager.fn_tasks_by_status('todo');

UPDATE task_manager.tasks
SET title = 'Prepare SRS 2 database - updated',
    status_id = (
        SELECT status_id
        FROM task_manager.task_statuses
        WHERE status_name = 'done'
    )
WHERE task_id = 1;

SELECT *
FROM task_manager.task_audit_logs
ORDER BY audit_id DESC;

SELECT *
FROM task_manager.statement_logs
ORDER BY statement_id DESC;

SELECT
    h.history_id,
    h.task_id,
    old_s.status_name AS old_status,
    new_s.status_name AS new_status,
    h.changed_by,
    h.changed_at
FROM task_manager.task_status_history h
LEFT JOIN task_manager.task_statuses old_s ON h.old_status_id = old_s.status_id
JOIN task_manager.task_statuses new_s ON h.new_status_id = new_s.status_id
ORDER BY h.history_id DESC;

INSERT INTO task_manager.active_tasks_view (
    project_id,
    created_by,
    assigned_to,
    status_name,
    priority_name,
    title,
    description,
    due_date
)
VALUES (
    1,
    2,
    3,
    'todo',
    'medium',
    'Inserted through view',
    'Бұл task INSTEAD OF trigger арқылы қосылды',
    CURRENT_DATE + 6
);

SELECT *
FROM task_manager.active_tasks_view
ORDER BY task_id DESC;

CREATE INDEX IF NOT EXISTS idx_tasks_created_at
ON task_manager.tasks(created_at);

SELECT *
FROM task_manager.ddl_logs
ORDER BY ddl_log_id DESC;

BEGIN;

CALL task_manager.sp_create_task(
    1,
    2,
    3,
    'Transaction commit task',
    'Бұл task COMMIT арқылы сақталады',
    'medium',
    CURRENT_DATE + 8
);

COMMIT;

SELECT *
FROM task_manager.tasks
WHERE title = 'Transaction commit task';

BEGIN;

UPDATE task_manager.tasks
SET title = 'Transaction test - first change'
WHERE task_id = 2;

SAVEPOINT sp_before_second_change;

UPDATE task_manager.tasks
SET title = 'This change will be rolled back'
WHERE task_id = 2;

ROLLBACK TO SAVEPOINT sp_before_second_change;

COMMIT;

SELECT task_id, title
FROM task_manager.tasks
WHERE task_id = 2;

BEGIN;

CALL task_manager.sp_create_task(
    1,
    2,
    3,
    'Rollback task',
    'Бұл task ROLLBACK кейін сақталмауы керек',
    'low',
    CURRENT_DATE + 2
);

ROLLBACK;

SELECT *
FROM task_manager.tasks
WHERE title = 'Rollback task';