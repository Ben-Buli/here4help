-- Create task_statuses table and seed data
CREATE TABLE IF NOT EXISTS task_statuses (
  id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  display_name VARCHAR(128) NOT NULL,
  progress_ratio DECIMAL(3,2) NOT NULL DEFAULT 0.00,
  sort_order INT NOT NULL DEFAULT 0,
  include_in_unread TINYINT(1) NOT NULL DEFAULT 1,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO task_statuses (code, display_name, progress_ratio, sort_order, include_in_unread, is_active)
VALUES
('open','Open',0.00,0,1,1),
('in_progress','In Progress',0.25,1,1,1),
('pending_confirmation','Pending Confirmation',0.50,2,1,1),
('dispute','Dispute',0.75,3,1,1),
('completed','Completed',1.00,4,0,1),
('applying','Applying',0.00,5,1,1),
('rejected','Rejected',1.00,6,0,1)
ON DUPLICATE KEY UPDATE display_name=VALUES(display_name);

