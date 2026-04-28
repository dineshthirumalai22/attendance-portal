const Database = require('better-sqlite3');
const path = require('path');

const dbPath = path.resolve(__dirname, 'attendance_central.db');
const db = new Database(dbPath);

// Initialize tables
db.exec(`
  CREATE TABLE IF NOT EXISTS classrooms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS students (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    register_number TEXT,
    gender TEXT,
    classroom_id INTEGER,
    FOREIGN KEY (classroom_id) REFERENCES classrooms (id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS attendance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER,
    classroom_id INTEGER,
    date TEXT,
    is_present INTEGER,
    FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
    FOREIGN KEY (classroom_id) REFERENCES classrooms (id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS profiles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    designation TEXT,
    institution TEXT,
    image_path TEXT
  );

  CREATE TABLE IF NOT EXISTS timetable (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    day TEXT,
    start_time TEXT,
    end_time TEXT,
    subject TEXT,
    period INTEGER DEFAULT 1,
    classroom_id INTEGER,
    FOREIGN KEY (classroom_id) REFERENCES classrooms (id) ON DELETE CASCADE
  );
`);

console.log('Database initialized at:', dbPath);

module.exports = db;
