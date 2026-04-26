import sqlite3
conn = sqlite3.connect('kui_backend/kui_db.sqlite')
c = conn.cursor()
c.execute('SELECT name FROM sqlite_master WHERE type=\"table\"')
tables = c.fetchall()
print('Tables in SQLite database:')
for table in tables:
    print(f'  {table[0]}')
    # Show schema for each table
    c.execute(f'PRAGMA table_info({table[0]})')
    columns = c.fetchall()
    for col in columns:
        print(f'    {col[1]} {col[2]}')
conn.close()