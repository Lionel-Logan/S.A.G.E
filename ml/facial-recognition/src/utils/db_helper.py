import sqlite3
import numpy as np
import io

def adapt_array(arr):
    """Convert numpy array to binary for SQLite."""
    out = io.BytesIO()
    np.save(out, arr)
    out.seek(0)
    return sqlite3.Binary(out.read())

def convert_array(blob):
    """Convert binary back to numpy array."""
    out = io.BytesIO(blob)
    out.seek(0)
    return np.load(out)

def init_db(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS people (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            embedding BLOB NOT NULL
        )
    ''')
    conn.commit()
    conn.close()