from flask import Flask
from flask_mysqldb import MySQL
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

app.config['MYSQL_HOST'] = os.getenv('DB_HOST')
app.config['MYSQL_USER'] = os.getenv('DB_USER')
app.config['MYSQL_PASSWORD'] = os.getenv('DB_PASSWORD')
app.config['MYSQL_DB'] = os.getenv('DB_NAME')

mysql = MySQL(app)

# Esto crea el contexto de aplicación
with app.app_context():
    try:
        cur = mysql.connection.cursor()
        cur.execute("SELECT 1")  # consulta simple para probar la conexión
        cur.close()
        print("Conexión a la base de datos exitosa ✅")
    except Exception as e:
        print("Error al conectar con la DB ❌:", e)
