from flask import Flask, request, jsonify
from flask_cors import CORS
import database
import pandas as pd
import io
import smtplib
import random
from email.mime.text import MIMEText
from flask import send_file

app = Flask(__name__)
CORS(app)

otp_store = {}

# Initialize DB on startup
database.init_db()

# --- Authentication Routes ---
@app.route('/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    
    conn = database.get_db_connection()
    user = conn.execute('SELECT * FROM users WHERE username = ? AND password = ?', (username, password)).fetchone()
    
    if user:
        profile = conn.execute('SELECT * FROM profiles WHERE user_id = ?', (user['id'],)).fetchone()
        conn.close()
        return jsonify({
            'status': 'success',
            'user': {
                'id': user['id'],
                'username': user['username'],
                'role': user['role']
            },
            'profile': dict(profile) if profile else None
        })
    
    conn.close()
    return jsonify({'status': 'fail', 'message': 'Invalid credentials'}), 401

@app.route('/staff', methods=['GET'])
def get_staff():
    conn = database.get_db_connection()
    staff = conn.execute("SELECT id, username, role FROM users").fetchall()
    conn.close()
    return jsonify([dict(row) for row in staff])

@app.route('/staff', methods=['POST'])
def add_staff():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    
    conn = database.get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute('INSERT INTO users (username, password, role) VALUES (?, ?, ?)', (username, password, 'admin'))
        user_id = cursor.lastrowid
        # Create a blank profile for the new staff
        cursor.execute('INSERT INTO profiles (name, designation, institution, user_id) VALUES (?, ?, ?, ?)', 
                       (username, 'Staff', 'Bharathidasan University', user_id))
        conn.commit()
        conn.close()
        return jsonify({'status': 'success', 'id': user_id})
    except Exception as e:
        conn.rollback()
        conn.close()
        return jsonify({'status': 'fail', 'message': str(e)}), 400

@app.route('/send-otp', methods=['POST'])
def send_otp():
    data = request.json
    email = data.get('email')
    if not email:
        return jsonify({'status': 'fail', 'message': 'Email is required'}), 400
    
    otp = str(random.randint(100000, 999999))
    otp_store[email] = otp
    
    try:
        sender_email = "divakar2272003@gmail.com"
        sender_password = "bohi ywar rysv sddg"
        
        msg = MIMEText(f"Your OTP for registration is: {otp}")
        msg['Subject'] = 'Registration OTP'
        msg['From'] = sender_email
        msg['To'] = email
        
        server = smtplib.SMTP_SSL('smtp.gmail.com', 465)
        server.login(sender_email, sender_password)
        server.send_message(msg)
        server.quit()
        
        return jsonify({'status': 'success', 'message': 'OTP sent'})
    except Exception as e:
        return jsonify({'status': 'fail', 'message': str(e)}), 500

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    name = data.get('name')
    designation = data.get('designation', 'User')
    institution = data.get('institution', '')
    email = data.get('email')
    otp = data.get('otp')
    
    if not email or not otp:
        return jsonify({'status': 'fail', 'message': 'Email and OTP are required'}), 400
        
    if otp_store.get(email) != otp:
        return jsonify({'status': 'fail', 'message': 'Invalid OTP'}), 400
        
    # Clear OTP
    if email in otp_store:
        del otp_store[email]
    
    conn = database.get_db_connection()
    cursor = conn.cursor()
    try:
        # Check if user already exists
        existing = cursor.execute('SELECT id FROM users WHERE username = ?', (username,)).fetchone()
        if existing:
            conn.close()
            return jsonify({'status': 'fail', 'message': 'Username already exists'}), 400
            
        cursor.execute('INSERT INTO users (username, password, role, email) VALUES (?, ?, ?, ?)', (username, password, 'admin', email))
        user_id = cursor.lastrowid
        
        cursor.execute('INSERT INTO profiles (name, designation, institution, user_id) VALUES (?, ?, ?, ?)', 
                       (name, designation, institution, user_id))
        
        conn.commit()
        conn.close()
        return jsonify({'status': 'success', 'user_id': user_id})
    except Exception as e:
        conn.rollback()
        conn.close()
        return jsonify({'status': 'fail', 'message': str(e)}), 400

@app.route('/forgot-password/send-otp', methods=['POST'])
def forgot_password_send_otp():
    data = request.json
    email = data.get('email')
    if not email:
        return jsonify({'status': 'fail', 'message': 'Email is required'}), 400
        
    conn = database.get_db_connection()
    user = conn.execute('SELECT * FROM users WHERE email = ?', (email,)).fetchone()
    conn.close()
    
    if not user:
        return jsonify({'status': 'fail', 'message': 'Email not registered'}), 404
        
    otp = str(random.randint(100000, 999999))
    otp_store[email] = otp
    
    try:
        sender_email = "divakar2272003@gmail.com"
        sender_password = "bohi ywar rysv sddg"
        
        msg = MIMEText(f"Your OTP for password reset is: {otp}")
        msg['Subject'] = 'Password Reset OTP'
        msg['From'] = sender_email
        msg['To'] = email
        
        server = smtplib.SMTP_SSL('smtp.gmail.com', 465)
        server.login(sender_email, sender_password)
        server.send_message(msg)
        server.quit()
        
        return jsonify({'status': 'success', 'message': 'OTP sent'})
    except Exception as e:
        return jsonify({'status': 'fail', 'message': str(e)}), 500

@app.route('/forgot-password/reset', methods=['POST'])
def forgot_password_reset():
    data = request.json
    email = data.get('email')
    otp = data.get('otp')
    new_password = data.get('new_password')
    
    if not email or not otp or not new_password:
        return jsonify({'status': 'fail', 'message': 'Missing parameters'}), 400
        
    if otp_store.get(email) != otp:
        return jsonify({'status': 'fail', 'message': 'Invalid OTP'}), 400
        
    conn = database.get_db_connection()
    conn.execute('UPDATE users SET password = ? WHERE email = ?', (new_password, email))
    conn.commit()
    conn.close()
    
    if email in otp_store:
        del otp_store[email]
        
    return jsonify({'status': 'success', 'message': 'Password reset successful'})

# --- Classroom Routes ---
@app.route('/classrooms', methods=['GET'])
def get_classrooms():
    user_id = request.args.get('user_id')
    conn = database.get_db_connection()
    if user_id:
        classrooms = conn.execute('SELECT * FROM classrooms WHERE user_id = ?', (user_id,)).fetchall()
    else:
        classrooms = conn.execute('SELECT * FROM classrooms').fetchall()
    conn.close()
    return jsonify([dict(row) for row in classrooms])

@app.route('/classrooms', methods=['POST'])
def add_classroom():
    data = request.json
    name = data.get('name')
    subject = data.get('subject', '')
    user_id = data.get('user_id')
    conn = database.get_db_connection()
    cursor = conn.cursor()
    cursor.execute('INSERT INTO classrooms (name, subject, user_id) VALUES (?, ?, ?)', (name, subject, user_id))
    new_id = cursor.lastrowid
    conn.commit()
    conn.close()
    return jsonify({'id': new_id, 'name': name, 'subject': subject, 'user_id': user_id})

@app.route('/classrooms/<int:id>', methods=['PUT'])
def update_classroom(id):
    data = request.json
    name = data.get('name')
    subject = data.get('subject')
    conn = database.get_db_connection()
    if subject is not None:
        conn.execute('UPDATE classrooms SET name = ?, subject = ? WHERE id = ?', (name, subject, id))
    else:
        conn.execute('UPDATE classrooms SET name = ? WHERE id = ?', (name, id))
    conn.commit()
    conn.close()
    return jsonify({'id': id, 'name': name, 'subject': subject})

@app.route('/classrooms/<int:id>', methods=['DELETE'])
def delete_classroom(id):
    conn = database.get_db_connection()
    conn.execute('DELETE FROM classrooms WHERE id = ?', (id,))
    conn.commit()
    conn.close()
    return '', 24

# --- Student Routes ---
@app.route('/classrooms/<int:classroom_id>/students', methods=['GET'])
def get_students(classroom_id):
    conn = database.get_db_connection()
    students = conn.execute('SELECT * FROM students WHERE classroom_id = ?', (classroom_id,)).fetchall()
    conn.close()
    return jsonify([dict(row) for row in students])

@app.route('/students', methods=['POST'])
def add_student():
    data = request.json
    conn = database.get_db_connection()
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO students (name, register_number, gender, classroom_id, parent_email) 
        VALUES (?, ?, ?, ?, ?)
    ''', (data['name'], data.get('register_number', ''), data.get('gender', ''), data['classroom_id'], data.get('parent_email', '')))
    new_id = cursor.lastrowid
    conn.commit()
    conn.close()
    return jsonify({**data, 'id': new_id})

@app.route('/students/<int:id>', methods=['PUT'])
def update_student(id):
    data = request.json
    conn = database.get_db_connection()
    conn.execute('''
        UPDATE students SET name = ?, register_number = ?, gender = ?, parent_email = ? WHERE id = ?
    ''', (data['name'], data.get('register_number', ''), data.get('gender', ''), data.get('parent_email', ''), id))
    conn.commit()
    conn.close()
    return jsonify({'status': 'updated'})

@app.route('/students/<int:id>', methods=['DELETE'])
def delete_student(id):
    conn = database.get_db_connection()
    conn.execute('DELETE FROM students WHERE id = ?', (id,))
    conn.commit()
    conn.close()
    return '', 24

# --- Attendance Routes ---
@app.route('/classrooms/<int:classroom_id>/attendance/<string:date>', methods=['GET'])
def get_attendance(classroom_id, date):
    conn = database.get_db_connection()
    attendance = conn.execute('''
        SELECT * FROM attendance WHERE classroom_id = ? AND date = ?
    ''', (classroom_id, date)).fetchall()
    conn.close()
    return jsonify([dict(row) for row in attendance])

@app.route('/attendance/batch', methods=['POST'])
def save_attendance_batch():
    reports = request.json
    conn = database.get_db_connection()
    cursor = conn.cursor()
    try:
        absent_student_ids = []
        for report in reports:
            cursor.execute('DELETE FROM attendance WHERE student_id = ? AND date = ?', 
                           (report['student_id'], report['date']))
            cursor.execute('''
                INSERT INTO attendance (student_id, classroom_id, date, is_present) 
                VALUES (?, ?, ?, ?)
            ''', (report['student_id'], report['classroom_id'], report['date'], report['is_present']))
            if report['is_present'] == 0:
                absent_student_ids.append((report['student_id'], report['date']))
        conn.commit()
        
        # Send absent emails
        for student_id, date in absent_student_ids:
            student = cursor.execute('SELECT name, parent_email FROM students WHERE id = ?', (student_id,)).fetchone()
            if student and student['parent_email']:
                parent_email = student['parent_email']
                student_name = student['name']
                
                # Send email
                sender_email = "divakar2272003@gmail.com"
                sender_password = "bohi ywar rysv sddg"
                msg = MIMEText(f"Dear Parent,\n\nThis is to inform you that your child {student_name} is marked as ABSENT on {date}.\n\nRegards,\nThe Institution")
                msg['Subject'] = f"Attendance Alert: {student_name} is Absent"
                msg['From'] = sender_email
                msg['To'] = parent_email
                
                try:
                    import smtplib
                    server = smtplib.SMTP_SSL('smtp.gmail.com', 465)
                    server.login(sender_email, sender_password)
                    server.send_message(msg)
                    server.quit()
                except Exception as eval_e:
                    print(f"Failed to send email to {parent_email}: {eval_e}")
                    
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()
    return jsonify({'status': 'saved'})

@app.route('/classrooms/<int:classroom_id>/summary', methods=['GET'])
def get_summary(classroom_id):
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')
    
    query = '''
        SELECT s.name, 
               COUNT(a.id) as total_days,
               SUM(CASE WHEN a.is_present = 1 THEN 1 ELSE 0 END) as present_days,
               SUM(CASE WHEN a.is_present = 0 THEN 1 ELSE 0 END) as absent_days,
               SUM(CASE WHEN a.is_present = 2 THEN 1 ELSE 0 END) as leave_days,
               SUM(CASE WHEN a.is_present = 3 THEN 1 ELSE 0 END) as od_days
        FROM students s
        LEFT JOIN attendance a ON s.id = a.student_id
        WHERE s.classroom_id = ?
    '''
    params = [classroom_id]
    
    if start_date:
        query += ' AND a.date >= ?'
        params.append(start_date)
    if end_date:
        query += ' AND a.date <= ?'
        params.append(end_date)
        
    query += ' GROUP BY s.id'
    
    conn = database.get_db_connection()
    rows = conn.execute(query, params).fetchall()
    conn.close()
    return jsonify([dict(row) for row in rows])

@app.route('/classrooms/<int:classroom_id>/date-wise-summary', methods=['GET'])
def get_date_wise_summary(classroom_id):
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')
    
    query = '''
        SELECT date, 
               COUNT(id) as total_attendance,
               SUM(CASE WHEN is_present = 1 THEN 1 ELSE 0 END) as present_count,
               SUM(CASE WHEN is_present = 0 THEN 1 ELSE 0 END) as absent_count,
               SUM(CASE WHEN is_present = 2 THEN 1 ELSE 0 END) as leave_count,
               SUM(CASE WHEN is_present = 3 THEN 1 ELSE 0 END) as od_count
        FROM attendance
        WHERE classroom_id = ?
    '''
    params = [classroom_id]
    
    if start_date:
        query += ' AND date >= ?'
        params.append(start_date)
    if end_date:
        query += ' AND date <= ?'
        params.append(end_date)
        
    query += ' GROUP BY date ORDER BY date DESC'
    
    conn = database.get_db_connection()
    rows = conn.execute(query, params).fetchall()
    conn.close()
    return jsonify([dict(row) for row in rows])

@app.route('/classrooms/<int:classroom_id>/month-wise-summary', methods=['GET'])
def get_month_wise_summary(classroom_id):
    # Group by YYYY-MM
    conn = database.get_db_connection()
    rows = conn.execute('''
        SELECT STRFTIME('%Y-%m', date) as month,
               COUNT(id) as total_attendance,
               SUM(CASE WHEN is_present = 1 THEN 1 ELSE 0 END) as present_count,
               SUM(CASE WHEN is_present = 0 THEN 1 ELSE 0 END) as absent_count,
               SUM(CASE WHEN is_present = 2 THEN 1 ELSE 0 END) as leave_count,
               SUM(CASE WHEN is_present = 3 THEN 1 ELSE 0 END) as od_count
        FROM attendance
        WHERE classroom_id = ?
        GROUP BY month
        ORDER BY month DESC
    ''', (classroom_id,)).fetchall()
    conn.close()
    return jsonify([dict(row) for row in rows])

# --- Profile Routes ---
@app.route('/profile/<int:user_id>', methods=['GET'])
def get_profile(user_id):
    conn = database.get_db_connection()
    # Join with users to get the role
    profile = conn.execute('''
        SELECT p.*, u.role 
        FROM profiles p 
        JOIN users u ON p.user_id = u.id 
        WHERE p.user_id = ?
    ''', (user_id,)).fetchone()
    conn.close()
    return jsonify(dict(profile) if profile else None)

@app.route('/profile', methods=['POST'])
def save_profile():
    data = request.json
    user_id = data.get('user_id')
    conn = database.get_db_connection()
    cursor = conn.cursor()
    existing = cursor.execute('SELECT id FROM profiles WHERE user_id = ?', (user_id,)).fetchone()
    
    if existing:
        cursor.execute('''
            UPDATE profiles SET name = ?, designation = ?, institution = ?, image_path = ? 
            WHERE user_id = ?
        ''', (data['name'], data['designation'], data['institution'], data.get('image_path'), user_id))
    else:
        cursor.execute('''
            INSERT INTO profiles (name, designation, institution, image_path, user_id) 
            VALUES (?, ?, ?, ?, ?)
        ''', (data['name'], data['designation'], data['institution'], data.get('image_path'), user_id))
    
    conn.commit()
    conn.close()
    return jsonify({'status': 'saved'})

# --- Timetable Routes ---
@app.route('/classrooms/<int:classroom_id>/timetable', methods=['GET'])
def get_timetable(classroom_id):
    conn = database.get_db_connection()
    entries = conn.execute('SELECT * FROM timetable WHERE classroom_id = ? ORDER BY day, period', (classroom_id,)).fetchall()
    conn.close()
    return jsonify([dict(row) for row in entries])

@app.route('/timetable', methods=['POST'])
def add_timetable_entry():
    data = request.json
    conn = database.get_db_connection()
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO timetable (day, start_time, end_time, subject, period, classroom_id) 
        VALUES (?, ?, ?, ?, ?, ?)
    ''', (data['day'], data['start_time'], data['end_time'], data['subject'], data.get('period', 1), data['classroom_id']))
    new_id = cursor.lastrowid
    conn.commit()
    conn.close()
    return jsonify({'id': new_id})

@app.route('/timetable/<int:id>', methods=['DELETE'])
def delete_timetable_entry(id):
    conn = database.get_db_connection()
    conn.execute('DELETE FROM timetable WHERE id = ?', (id,))
    conn.commit()
    conn.close()
    return '', 24

@app.route('/backup/excel', methods=['GET'])
def backup_excel():
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({'status': 'fail', 'message': 'user_id is required'}), 400
        
    conn = database.get_db_connection()
    
    # 1. Classrooms
    df_classes = pd.read_sql_query('SELECT id, name, subject FROM classrooms WHERE user_id = ?', conn, params=(user_id,))
    
    # 2. Students
    # We join with classrooms to show the class name in the student list
    df_students = pd.read_sql_query('''
        SELECT s.name, s.register_number, s.gender, c.name as classroom_name 
        FROM students s
        JOIN classrooms c ON s.classroom_id = c.id
        WHERE c.user_id = ?
    ''', conn, params=(user_id,))
    
    # 3. Attendance
    df_attendance = pd.read_sql_query('''
        SELECT s.name as student_name, a.date, 
               CASE a.is_present WHEN 1 THEN 'Present' WHEN 0 THEN 'Absent' WHEN 3 THEN 'OD' ELSE 'Leave' END as status,
               c.name as classroom_name
        FROM attendance a
        JOIN students s ON a.student_id = s.id
        JOIN classrooms c ON a.classroom_id = c.id
        WHERE c.user_id = ?
    ''', conn, params=(user_id,))
    
    conn.close()
    
    # Create Excel in memory
    output = io.BytesIO()
    with pd.ExcelWriter(output, engine='openpyxl') as writer:
        df_classes.to_excel(writer, sheet_name='Classrooms', index=False)
        df_students.to_excel(writer, sheet_name='Students', index=False)
        df_attendance.to_excel(writer, sheet_name='Attendance', index=False)
        
    output.seek(0)
    
    return send_file(
        output,
        mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        as_attachment=True,
        download_name='attendance_backup.xlsx'
    )

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3000, debug=True)
