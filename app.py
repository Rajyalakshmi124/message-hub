from flask import Flask, request, render_template, jsonify, redirect, url_for, session
from pymongo import MongoClient
import os

app = Flask(__name__)

# Secure random secret key for sessions
app.secret_key = os.urandom(24)

try:
    # Get MongoDB URI from environment variable (set in Azure)
    MONGODB_URI = os.environ.get("MONGODB_URI")
    print(f"Attempting to connect to MongoDB using URI: {MONGODB_URI}")
    
    client = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=10000)
    client.admin.command('ismaster')  # quick connectivity check
    
    print("Successfully connected to MongoDB.")
    db = client.message_db
    collection = db.messages
except Exception as e:
    print("Could not connect to MongoDB.")
    print(f"Error: {e}")
    collection = None  # graceful fallback

# Predefined credentials
USERS = {
    "Administrator": "Pwd&1234",
    "Super admin": "Pwd&1234",
    "User A": "Pwd&1234",
    "User B": "Pwd&1234"
}

@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        if username in USERS and USERS[username] == password:
            session['username'] = username
            return redirect(url_for('index'))
        else:
            error = 'Invalid credentials. Please try again.'
    return render_template('login.html', error=error)

@app.route('/')
def index():
    if 'username' not in session:
        return redirect(url_for('login'))
    return render_template('index.html')

@app.route('/send', methods=['POST'])
def send():
    if 'username' not in session:
        return jsonify({"error": "Unauthorized"}), 401
    if collection is not None:
        message_text = request.form.get('message')
        timestamp_str = request.form.get('timestamp')
        if message_text and timestamp_str:
            collection.insert_one({'message': message_text, 'timestamp': timestamp_str})
    return '', 204

@app.route('/retrieve')
def retrieve():
    if 'username' not in session:
        return jsonify({"error": "Unauthorized"}), 401
    if collection is not None:
        messages = list(collection.find({}, {'_id': 0}).sort('_id', -1).limit(10))
        return jsonify(messages)
    return jsonify([])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
