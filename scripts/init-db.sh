#!/bin/bash
# Initialize FrameForge database with all required tables

set -e

echo "Initializing FrameForge database..."

# Wait for postgres to be ready
echo "Waiting for PostgreSQL to be ready..."
until docker exec frameforge-postgres pg_isready -U frameforge > /dev/null 2>&1; do
  sleep 1
done

echo "Creating database tables..."

# Create users table
docker exec frameforge-postgres psql -U frameforge -d frameforge -c "
CREATE TABLE IF NOT EXISTS users (
  \"userId\" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username varchar(50) UNIQUE NOT NULL,
  email varchar(255) UNIQUE NOT NULL,
  \"passwordHash\" varchar(255) NOT NULL,
  \"createdAt\" timestamp DEFAULT NOW() NOT NULL,
  \"updatedAt\" timestamp DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
" > /dev/null

echo "✅ Users table created"

# Create video_jobs table
docker exec frameforge-postgres psql -U frameforge -d frameforge -c "
CREATE TABLE IF NOT EXISTS video_jobs (
  \"jobId\" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  \"userId\" uuid NOT NULL,
  filename varchar(255) NOT NULL,
  status varchar(20) NOT NULL CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  \"videoUrl\" text NOT NULL,
  \"resultUrl\" text,
  \"frameCount\" integer,
  \"errorMessage\" text,
  \"createdAt\" timestamp DEFAULT NOW() NOT NULL,
  \"startedAt\" timestamp,
  \"completedAt\" timestamp,
  FOREIGN KEY (\"userId\") REFERENCES users(\"userId\") ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_video_jobs_user ON video_jobs(\"userId\");
CREATE INDEX IF NOT EXISTS idx_video_jobs_status ON video_jobs(status);
" > /dev/null

echo "✅ Video jobs table created"

# Create notification_log table
docker exec frameforge-postgres psql -U frameforge -d frameforge -c "
CREATE TABLE IF NOT EXISTS notification_log (
  \"notificationId\" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  \"userId\" uuid NOT NULL,
  \"jobId\" uuid NOT NULL,
  type varchar(50) NOT NULL,
  recipient varchar(255) NOT NULL,
  subject varchar(255),
  status varchar(20) NOT NULL CHECK (status IN ('pending', 'sent', 'failed')),
  \"sentAt\" timestamp,
  \"errorMessage\" text,
  \"retryCount\" integer DEFAULT 0 NOT NULL,
  \"createdAt\" timestamp DEFAULT NOW() NOT NULL,
  FOREIGN KEY (\"userId\") REFERENCES users(\"userId\") ON DELETE CASCADE,
  FOREIGN KEY (\"jobId\") REFERENCES video_jobs(\"jobId\") ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_notification_log_user ON notification_log(\"userId\");
CREATE INDEX IF NOT EXISTS idx_notification_log_job ON notification_log(\"jobId\");
CREATE INDEX IF NOT EXISTS idx_notification_log_status ON notification_log(status);
" > /dev/null

echo "✅ Notification log table created"

echo ""
echo "✅ Database initialization completed successfully!"
echo ""
echo "Tables created:"
echo "  - users (with indexes on username and email)"
echo "  - video_jobs (with indexes on userId and status)"
echo "  - notification_log (with indexes on userId, jobId, and status)"
