const express = require('express');
const cors = require('cors');
const db = require('./database');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// --- Classroom Routes ---
app.get('/classrooms', (req, res) => {
    const classrooms = db.prepare('SELECT * FROM classrooms').all();
    res.json(classrooms);
});

app.post('/classrooms', (req, res) => {
    const { name } = req.body;
    const info = db.prepare('INSERT INTO classrooms (name) VALUES (?)').run(name);
    res.json({ id: info.lastInsertRowid, name });
});

app.delete('/classrooms/:id', (req, res) => {
    db.prepare('DELETE FROM classrooms WHERE id = ?').run(req.params.id);
    res.status(204).end();
});

// --- Student Routes ---
app.get('/classrooms/:classroomId/students', (req, res) => {
    const students = db.prepare('SELECT * FROM students WHERE classroom_id = ?').all(req.params.classroomId);
    res.json(students);
});

app.post('/students', (req, res) => {
    const { name, register_number, gender, classroom_id } = req.body;
    const info = db.prepare('INSERT INTO students (name, register_number, gender, classroom_id) VALUES (?, ?, ?, ?)')
        .run(name, register_number, gender, classroom_id);
    res.json({ id: info.lastInsertRowid, name, register_number, gender, classroom_id });
});

app.put('/students/:id', (req, res) => {
    const { name, register_number, gender } = req.body;
    db.prepare('UPDATE students SET name = ?, register_number = ?, gender = ? WHERE id = ?')
        .run(name, register_number, gender, req.params.id);
    res.status(200).json({ status: 'updated' });
});

app.delete('/students/:id', (req, res) => {
    db.prepare('DELETE FROM students WHERE id = ?').run(req.params.id);
    res.status(204).end();
});

// --- Attendance Routes ---
app.get('/classrooms/:classroomId/attendance/:date', (req, res) => {
    const attendance = db.prepare('SELECT * FROM attendance WHERE classroom_id = ? AND date = ?')
        .all(req.params.classroomId, req.params.date);
    res.json(attendance);
});

app.post('/attendance/batch', (req, res) => {
    const reports = req.body; // Array of attendance objects
    const insert = db.prepare('INSERT INTO attendance (student_id, classroom_id, date, is_present) VALUES (?, ?, ?, ?)');
    const deleteOld = db.prepare('DELETE FROM attendance WHERE student_id = ? AND date = ?');

    const transaction = db.transaction((data) => {
        for (const report of data) {
            deleteOld.run(report.student_id, report.date);
            insert.run(report.student_id, report.classroom_id, report.date, report.is_present);
        }
    });

    transaction(reports);
    res.json({ status: 'saved' });
});

app.get('/classrooms/:classroomId/summary', (req, res) => {
    const { start_date, end_date } = req.query;
    let query = `
    SELECT s.name, 
           COUNT(a.id) as total_days,
           SUM(CASE WHEN a.is_present = 1 THEN 1 ELSE 0 END) as present_days,
           SUM(CASE WHEN a.is_present = 0 THEN 1 ELSE 0 END) as absent_days,
           SUM(CASE WHEN a.is_present = 2 THEN 1 ELSE 0 END) as leave_days,
           SUM(CASE WHEN a.is_present = 3 THEN 1 ELSE 0 END) as od_days
    FROM students s
    LEFT JOIN attendance a ON s.id = a.student_id
    WHERE s.classroom_id = ?
  `;
    const params = [req.params.classroomId];

    if (start_date && end_date) {
        query += ' AND a.date BETWEEN ? AND ?';
        params.push(start_date, end_date);
    }

    query += ' GROUP BY s.id';

    const rows = db.prepare(query).all(...params);
    res.json(rows);
});

app.get('/classrooms/:classroomId/date-wise-summary', (req, res) => {
    const { start_date, end_date } = req.query;
    let query = 'SELECT date, COUNT(id) as total_attendance, SUM(CASE WHEN is_present = 1 THEN 1 ELSE 0 END) as present_count, SUM(CASE WHEN is_present = 0 THEN 1 ELSE 0 END) as absent_count, SUM(CASE WHEN is_present = 2 THEN 1 ELSE 0 END) as leave_count, SUM(CASE WHEN is_present = 3 THEN 1 ELSE 0 END) as od_count FROM attendance WHERE classroom_id = ?';
    const params = [req.params.classroomId];

    if (start_date && end_date) {
        query += ' AND date BETWEEN ? AND ?';
        params.push(start_date, end_date);
    }

    query += ' GROUP BY date ORDER BY date DESC';

    const rows = db.prepare(query).all(...params);
    res.json(rows);
});

app.get('/classrooms/:classroomId/month-wise-summary', (req, res) => {
    const rows = db.prepare(`
    SELECT strftime('%Y-%m', date) as month,
           COUNT(id) as total_attendance,
           SUM(CASE WHEN is_present = 1 THEN 1 ELSE 0 END) as present_count,
           SUM(CASE WHEN is_present = 0 THEN 1 ELSE 0 END) as absent_count,
           SUM(CASE WHEN is_present = 2 THEN 1 ELSE 0 END) as leave_count,
           SUM(CASE WHEN is_present = 3 THEN 1 ELSE 0 END) as od_count
    FROM attendance
    WHERE classroom_id = ?
    GROUP BY month
    ORDER BY month DESC
  `).all(req.params.classroomId);
    res.json(rows);
});

// --- Authentication & Staff Routes ---
app.post('/login', (req, res) => {
    const { username, password } = req.body;
    // VERY BASIC AUTH for demonstration - in production use hashing and proper user table
    if (username === 'admin' && password === 'admin123') {
        res.json({
            user: { id: 1, username: 'admin', role: 'admin' },
            profile: db.prepare('SELECT * FROM profiles WHERE id = 1').get()
        });
    } else {
        const staff = db.prepare('SELECT * FROM profiles WHERE name = ? AND designation = "Staff"').get(username);
        if (staff && password === 'staff123') {
            res.json({
                user: { id: staff.id, username: staff.name, role: 'staff' },
                profile: staff
            });
        } else {
            res.status(401).json({ message: 'Invalid credentials' });
        }
    }
});

app.get('/staff', (req, res) => {
    const staff = db.prepare('SELECT * FROM profiles WHERE designation = "Staff"').all();
    res.json(staff);
});

app.post('/staff', (req, res) => {
    const { username, password } = req.body;
    const info = db.prepare('INSERT INTO profiles (name, designation, institution) VALUES (?, ?, ?)')
        .run(username, 'Staff', 'Institution');
    res.json({ id: info.lastInsertRowid, status: 'Staff added' });
});

// --- Profile Routes ---
app.get('/profile/:userId', (req, res) => {
    const profile = db.prepare('SELECT * FROM profiles WHERE id = ?').get(req.params.userId);
    res.json(profile || null);
});

app.post('/profile', (req, res) => {
    const { id, name, designation, institution, image_path } = req.body;
    const existing = id ? db.prepare('SELECT id FROM profiles WHERE id = ?').get(id) : null;

    if (existing) {
        db.prepare('UPDATE profiles SET name = ?, designation = ?, institution = ?, image_path = ? WHERE id = ?')
            .run(name, designation, institution, image_path, existing.id);
    } else {
        db.prepare('INSERT INTO profiles (name, designation, institution, image_path) VALUES (?, ?, ?, ?)')
            .run(name, designation, institution, image_path);
    }
    res.json({ status: 'saved' });
});

// --- Timetable Routes ---
app.get('/classrooms/:classroomId/timetable', (req, res) => {
    const entries = db.prepare('SELECT * FROM timetable WHERE classroom_id = ? ORDER BY day, period')
        .all(req.params.classroomId);
    res.json(entries);
});

app.post('/timetable', (req, res) => {
    const { day, start_time, end_time, subject, period, classroom_id } = req.body;
    const info = db.prepare('INSERT INTO timetable (day, start_time, end_time, subject, period, classroom_id) VALUES (?, ?, ?, ?, ?, ?)')
        .run(day, start_time, end_time, subject, period, classroom_id);
    res.json({ id: info.lastInsertRowid });
});

app.delete('/timetable/:id', (req, res) => {
    db.prepare('DELETE FROM timetable WHERE id = ?').run(req.params.id);
    res.status(204).end();
});

app.listen(port, () => {
    console.log(`Attendance server running at http://localhost:${port}`);
});
