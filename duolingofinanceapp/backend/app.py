from flask import Flask, request, jsonify
from flask_mysqldb import MySQL
from flask_bcrypt import Bcrypt
from dotenv import load_dotenv
import os

load_dotenv()

app = Flask(__name__)

# -------------------- Configuración DB --------------------
app.config['MYSQL_HOST'] = os.getenv('DB_HOST')
app.config['MYSQL_USER'] = os.getenv('DB_USER')
app.config['MYSQL_PASSWORD'] = os.getenv('DB_PASSWORD')
app.config['MYSQL_DB'] = os.getenv('DB_NAME')

mysql = MySQL(app)
bcrypt = Bcrypt(app)

# ===========================
# REGISTRO DE USUARIOS
# ===========================
@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')

    if not all([username, email, password]):
        return jsonify({"error": "Faltan datos"}), 400

    hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')

    cur = mysql.connection.cursor()
    cur.execute(
        "INSERT INTO users (username, email, password) VALUES (%s, %s, %s)",
        (username, email, hashed_password)
    )
    mysql.connection.commit()
    cur.close()

    return jsonify({"message": "Usuario registrado exitosamente!"}), 201

# ===========================
# LOGIN
# ===========================
@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    if not all([email, password]):
        return jsonify({"error": "Faltan datos"}), 400

    cur = mysql.connection.cursor()
    cur.execute("SELECT id_user, username, password FROM users WHERE email=%s", (email,))
    user = cur.fetchone()
    cur.close()

    if user and bcrypt.check_password_hash(user[2], password):
        return jsonify({"message": "Login exitoso", "username": user[1], "id_user": user[0]})
    else:
        return jsonify({"error": "Credenciales inválidas"}), 401

# ===========================
# AGREGAR MOVIMIENTO
# ===========================
@app.route('/movements', methods=['POST'])
def add_movement():
    data = request.get_json()
    id_user = data.get('id_user')
    categoria = data.get('categoria')
    nota = data.get('nota')
    monto = data.get('monto')
    tipo = data.get('tipo', 'Egreso')  # default Egreso si no se envía

    if not all([id_user, categoria, monto]):
        return jsonify({'error': 'Faltan datos'}), 400

    cur = mysql.connection.cursor()
    cur.execute(
        "INSERT INTO movimientos (user_id, categoria, nota, monto, tipo) VALUES (%s, %s, %s, %s, %s)",
        (id_user, categoria, nota, monto, tipo)
    )
    mysql.connection.commit()
    cur.close()
    return jsonify({'message': 'Movimiento agregado exitosamente'}), 201

# ===========================
# OBTENER MOVIMIENTOS POR USUARIO
# ===========================
@app.route('/movements/<int:id_user>', methods=['GET'])
def get_movements(id_user):
    cur = mysql.connection.cursor()
    cur.execute("SELECT * FROM movimientos WHERE user_id=%s ORDER BY fecha DESC", (id_user,))
    movimientos = cur.fetchall()
    cur.close()

    movimientos_list = [
        {
            "id_movimiento": m[0],
            "user_id": m[1],
            "fecha": str(m[2]),
            "monto": float(m[3]),
            "categoria": m[4],
            "nota": m[5],
            "tipo": m[6]
        }
        for m in movimientos
    ]
    return jsonify(movimientos_list)

# ===========================
# ACTUALIZAR MOVIMIENTO
# ===========================
@app.route('/movements/<int:id_movimiento>', methods=['PUT'])
def update_movement(id_movimiento):
    data = request.get_json()
    categoria = data.get('categoria')
    nota = data.get('nota')
    monto = data.get('monto')
    tipo = data.get('tipo', 'Egreso')

    if not all([categoria, monto]):
        return jsonify({'error': 'Faltan datos'}), 400

    cur = mysql.connection.cursor()
    cur.execute(
        "UPDATE movimientos SET categoria=%s, nota=%s, monto=%s, tipo=%s WHERE id_movimiento=%s",
        (categoria, nota, monto, tipo, id_movimiento)
    )
    mysql.connection.commit()
    cur.close()
    return jsonify({'message': 'Movimiento actualizado exitosamente'})

# ===========================
# ELIMINAR MOVIMIENTO
# ===========================
@app.route('/movements/<int:id_movimiento>', methods=['DELETE'])
def delete_movement(id_movimiento):
    cur = mysql.connection.cursor()
    cur.execute("DELETE FROM movimientos WHERE id_movimiento=%s", (id_movimiento,))
    mysql.connection.commit()
    cur.close()
    return jsonify({'message': 'Movimiento eliminado exitosamente'})

# ===========================
# RESUMEN POR CATEGORÍA
# ===========================
@app.route('/movements/summary/<int:id_user>', methods=['GET'])
def movements_summary(id_user):
    cur = mysql.connection.cursor()
    cur.execute(
        "SELECT categoria, SUM(monto) as total FROM movimientos WHERE user_id=%s GROUP BY categoria",
        (id_user,)
    )
    resumen = cur.fetchall()
    cur.close()

    resumen_list = [{"categoria": r[0], "total": float(r[1])} for r in resumen]
    return jsonify(resumen_list)

# ===========================
# BALANCE GENERAL
# ===========================
@app.route('/balance/<int:id_user>', methods=['GET'])
def balance(id_user):
    cur = mysql.connection.cursor()
    cur.execute("SELECT tipo, SUM(monto) FROM movimientos WHERE user_id=%s GROUP BY tipo", (id_user,))
    resultados = cur.fetchall()
    cur.close()

    ingresos = 0
    egresos = 0
    for r in resultados:
        if r[0] == 'Ingreso':
            ingresos = float(r[1])
        elif r[0] == 'Egreso':
            egresos = float(r[1])

    balance_total = ingresos - egresos
    return jsonify({"ingresos": ingresos, "egresos": egresos, "balance": balance_total})

# ===========================
# RUN
# ===========================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
