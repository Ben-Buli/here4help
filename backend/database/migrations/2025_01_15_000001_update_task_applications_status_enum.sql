-- Update task_applications status ENUM to include all required statuses
-- This migration adds missing status values to support the complete application lifecycle

-- First, check if the table exists and what the current ENUM values are
-- ALTER TABLE task_applications MODIFY COLUMN status ENUM('applied', 'accepted', 'rejected', 'pending', 'completed', 'cancelled', 'dispute', 'withdrawn') DEFAULT 'applied';

-- For safety, we'll use a more compatible approach that works with existing data
ALTER TABLE task_applications 
MODIFY COLUMN status VARCHAR(50) NOT NULL DEFAULT 'applied';

-- Add index for better performance on status queries
CREATE INDEX IF NOT EXISTS idx_task_applications_status ON task_applications(status);

-- Update any legacy status values to match the new standard
UPDATE task_applications SET status = 'applied' WHERE status = 'pending';
UPDATE task_applications SET status = 'accepted' WHERE status = 'approved';

-- Add a comment to document the allowed values
ALTER TABLE task_applications 
MODIFY COLUMN status VARCHAR(50) NOT NULL DEFAULT 'applied' 
COMMENT 'Allowed values: applied, accepted, rejected, pending, completed, cancelled, dispute, withdrawn';
