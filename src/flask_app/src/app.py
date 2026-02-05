import os
import pymysql.cursors
import logging
from flask import Flask, render_template, jsonify, send_from_directory

# --- 1. Configure Logging ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# --- Initialize Flask App ---
app = Flask(__name__)

# --- Configuration ---
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_USER = os.getenv('DB_USER', 'asterisk_user')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'asterisk_password')
DB_NAME = os.getenv('DB_NAME', 'asterisk_db')

# IMPROVEMENT: Define the path where recordings are mounted inside this container
RECORDING_DIR = '/recordings' # This is the mount point inside the container

def get_db_connection():
    """Establishes and logs the connection to the database."""
    try:
        app.logger.info(f"Attempting to connect to database at host: {DB_HOST}")
        connection = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            connect_timeout=5,
            cursorclass=pymysql.cursors.DictCursor
        )
        app.logger.info("Database connection successful.")
        return connection
    except pymysql.MySQLError as e:
        app.logger.error(f"FATAL: Could not connect to the database: {e}")
        raise e

# --- API and Page Routes ---

@app.route('/')
def index():
    """Serves the main call page from templates/call.html."""
    return render_template('call.html')

@app.route('/calls', methods=['GET'])
def get_calls():
    """API endpoint to fetch recent call detail records from our NEW table."""
    connection = None
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            app.logger.info("Executing query to fetch from new call_logs table.")
            
            sql = "SELECT uniqueid, call_start, call_end, caller_id, destination, duration, disposition, recording_path FROM call_logs ORDER BY call_start DESC LIMIT 50"
            
            cursor.execute(sql)
            result = cursor.fetchall()
            app.logger.info(f"Successfully fetched {len(result)} records from call_logs.")
            
            # Convert datetime objects to strings for JSON serialization
            for row in result:
                if row.get('call_start'):
                    row['call_start'] = row['call_start'].strftime('%Y-%m-%d %H:%M:%S')
                if row.get('call_end'):
                    row['call_end'] = row['call_end'].strftime('%Y-%m-%d %H:%M:%S')
                
                # --- CRITICAL IMPROVEMENT: Extract only the basename (filename) ---
                if row.get('recording_path'):
                    row['recording_path'] = os.path.basename(row['recording_path'])
                    app.logger.debug(f"Original path: {row['recording_path']}, Extracted filename: {row['recording_path']}") # Use debug for less verbose logging
                else:
                    app.logger.debug(f"No recording_path for uniqueid: {row.get('uniqueid')}")

            return jsonify(result)

    except Exception as e:
        app.logger.error(f"An error occurred while fetching call logs: {e}", exc_info=True)
        return jsonify({"error": "An internal error occurred. Check server logs for details."}), 500
        
    finally:
        if connection:
            app.logger.info("Closing database connection.")
            connection.close()

# --- NEW: Route to serve recording files ---
@app.route('/recordings/<path:filename>')
def serve_recording(filename):
    """Securely serves a recording file from the shared volume."""
    app.logger.info(f"Request received for recording file: {filename} from {RECORDING_DIR}")
    
    # Use send_from_directory directly. It handles path joining and security.
    # The filename passed from the client should now be just the basename.
    try:
        return send_from_directory(RECORDING_DIR, filename, as_attachment=False)
    except FileNotFoundError:
        app.logger.error(f"File not found in {RECORDING_DIR}: {filename}")
        return jsonify({"error": "File not found"}), 404
    except Exception as e:
        app.logger.error(f"An error occurred while serving recording {filename}: {e}", exc_info=True)
        return jsonify({"error": "An internal error occurred while serving the file."}), 500


# --- Diagnostic Route (Unchanged) ---
@app.route('/debug')
def debug_info():
    """Diagnostic route to verify static file existence and paths."""
    root_path = app.root_path
    static_folder = app.static_folder # This is an absolute path
    js_file_to_check = 'js/sip-0.7.8.js'
    expected_js_path = os.path.join(static_folder, js_file_to_check)
    js_file_exists = os.path.exists(expected_js_path)
    css_file_to_check = 'style.css'
    expected_css_path = os.path.join(static_folder, css_file_to_check)
    css_file_exists = os.path.exists(expected_css_path)
    
    # Add a check for the recording directory itself
    recording_dir_exists = os.path.exists(RECORDING_DIR)
    
    return f"""
        <html>
        <head><title>Flask Debug Info</title></head>
        <body>
            <h1>Flask Static File Debug Info</h1>
            <p>This information shows what the running Flask server is looking for inside the container.</p>
            <hr>
            <p><strong>Application Root Path:</strong><br><code>{root_path}</code></p>
            <p><strong>Configured Static Folder (Absolute Path):</strong><br><code>{static_folder}</code></p>
            <p><strong>Configured Recording Directory (Absolute Path in Container):</strong><br><code>{RECORDING_DIR}</code></p>
            <p style="font-size: 1.2em; font-weight: bold; color: {'green' if recording_dir_exists else 'red'};">
                Recording Directory Exists: {recording_dir_exists}
            </p>
            <hr>
            <h2>File Checks</h2>
            <h3>Checking for: <code>{js_file_to_check}</code></h3>
            <p><strong>Expected Full Path:</strong><br><code>{expected_js_path}</code></p>
            <p style="font-size: 1.2em; font-weight: bold; color: {'green' if js_file_exists else 'red'};">
                Exists on Filesystem: {js_file_exists}
            </p>
            <h3>Checking for: <code>{css_file_to_check}</code></h3>
            <p><strong>Expected Full Path:</strong><br><code>{expected_css_path}</code></p>
            <p style="font-size: 1.2em; font-weight: bold; color: {'green' if css_file_exists else 'red'};">
                Exists on Filesystem: {css_file_exists}
            </p>
        </body>
        </html>
    """

if __name__ == '__main__':
    # --- Log startup configuration ---
    app.logger.info("Flask application starting up...")
    app.logger.info(f"Database host set to: {DB_HOST}")
    app.logger.info(f"Database user set to: {DB_USER}")
    app.logger.info(f"Database name set to: {DB_NAME}")
    app.logger.info(f"Serving recordings from internal path: {RECORDING_DIR}")

    app.run(host='0.0.0.0', port=5000, debug=True)