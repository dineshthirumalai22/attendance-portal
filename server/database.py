import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), 'attendance_central.db')

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Enable foreign keys
    cursor.execute('PRAGMA foreign_keys = ON')
    
    cursor.executescript('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT DEFAULT 'admin' -- Changed default to admin
        );

        CREATE TABLE IF NOT EXISTS classrooms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            subject TEXT,
            user_id INTEGER,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
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
            image_path TEXT,
            user_id INTEGER UNIQUE,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
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
    ''')
    
    # Migration: Add subject column if it doesn't exist
    try:
        cursor.execute("ALTER TABLE classrooms ADD COLUMN subject TEXT")
    except sqlite3.OperationalError:
        pass # Column already exists
        
    # Migration: Add email column if it doesn't exist
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN email TEXT")
    except sqlite3.OperationalError:
        pass # Column already exists
        
    # Migration: Add parent_email column to students
    try:
        cursor.execute("ALTER TABLE students ADD COLUMN parent_email TEXT")
    except sqlite3.OperationalError:
        pass
        
    conn.commit()
    conn.close()
    print(f"Database initialized at: {DB_PATH}")

if __name__ == "__main__":
    init_db()
