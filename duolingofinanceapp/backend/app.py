from flask import Flask, request, jsonify
from flask_mysqldb import MySQL
from flask_bcrypt import Bcrypt
from dotenv import load_dotenv
from google import genai
from google.genai.errors import APIError
from datetime import datetime, timedelta
import os

# -------------------------------
# Cargar variables de entorno
# -------------------------------
load_dotenv()

app = Flask(__name__)

# -------------------------------
# Configuración MySQL
# -------------------------------
app.config['MYSQL_HOST'] = os.getenv('DB_HOST')
app.config['MYSQL_USER'] = os.getenv('DB_USER')
app.config['MYSQL_PASSWORD'] = os.getenv('DB_PASSWORD')
app.config['MYSQL_DB'] = os.getenv('DB_NAME')

mysql = MySQL(app)
bcrypt = Bcrypt(app)

# -------------------------------
# Configuración Gemini AI
# -------------------------------
# -------------------- CONFIGURACIÓN DE GEMINI (IA) --------------------
# 2. Reemplaza 'GEMINI_API_KEY' con el nombre de tu variable de entorno real
#    que contiene la clave API de Google Gemini.
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
if GEMINI_API_KEY:
    client = genai.Client(api_key=GEMINI_API_KEY)
    MODEL = 'gemini-2.5-flash'  # Modelo rápido y eficiente para chat y análisis
else:
    print("ADVERTENCIA: GEMINI_API_KEY no está configurada.")
# ----------------------------------------------------------------------

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
# MOVIMIENTOS (CRUD)
# ===========================
@app.route('/movements', methods=['POST'])
def add_movement():
    data = request.get_json()
    id_user = data.get('id_user')
    categoria = data.get('categoria')
    nota = data.get('nota')
    monto = data.get('monto')
    tipo = data.get('tipo', 'Egreso')

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

@app.route('/movements/<int:id_movimiento>', methods=['DELETE'])
def delete_movement(id_movimiento):
    cur = mysql.connection.cursor()
    cur.execute("DELETE FROM movimientos WHERE id_movimiento=%s", (id_movimiento,))
    mysql.connection.commit()
    cur.close()
    return jsonify({'message': 'Movimiento eliminado exitosamente'})

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

@app.route('/balance/<int:id_user>', methods=['GET'])
def balance(id_user):
    cur = mysql.connection.cursor()
    cur.execute("SELECT tipo, SUM(monto) FROM movimientos WHERE user_id=%s GROUP BY tipo", (id_user,))
    resultados = cur.fetchall()
    cur.close()

    ingresos = float(next((r[1] for r in resultados if r[0] == 'Ingreso'), 0))
    egresos = float(next((r[1] for r in resultados if r[0] == 'Egreso'), 0))
    return jsonify({"ingresos": ingresos, "egresos": egresos, "balance": ingresos - egresos})

# ===========================
# METAS DE AHORRO
# ===========================
@app.route('/goals/ahorro/<int:id_user>', methods=['GET'])
def get_ahorro_goals(id_user):
    cur = mysql.connection.cursor()
    cur.execute(
        "SELECT id_meta, descripcion, monto_objetivo, monto_actual FROM metas_ahorro WHERE user_id=%s",
        (id_user,)
    )
    metas = cur.fetchall()
    cur.close()
    metas_list = [
        {
            "id_ahorro": m[0],
            "nombre_meta": m[1],
            "monto_objetivo": float(m[2]),
            "monto_actual": float(m[3])
        } for m in metas
    ]
    return jsonify(metas_list)

@app.route('/goals/ahorro', methods=['POST'])
def create_ahorro_goal():
    data = request.get_json()
    user_id = data.get('id_user')
    nombre_meta = data.get('nombre_meta')
    monto_objetivo = data.get('monto_objetivo')

    if not all([user_id, nombre_meta, monto_objetivo]):
        return jsonify({"error": "Faltan datos"}), 400

    cur = mysql.connection.cursor()
    cur.execute(
        "INSERT INTO metas_ahorro (user_id, descripcion, monto_objetivo) VALUES (%s, %s, %s)",
        (user_id, nombre_meta, monto_objetivo)
    )
    mysql.connection.commit()
    cur.close()
    return jsonify({"message": "Meta de ahorro creada exitosamente"}), 201

@app.route('/goals/ahorro/<int:id_meta>', methods=['PUT'])
def update_ahorro_goal(id_meta):
    data = request.get_json()
    monto_actual = data.get('monto_actual')
    monto_objetivo = data.get('monto_objetivo')

    if monto_actual is None and monto_objetivo is None:
        return jsonify({"error": "No hay datos para actualizar"}), 400

    cur = mysql.connection.cursor()
    if monto_actual is not None and monto_objetivo is not None:
        cur.execute(
            "UPDATE metas_ahorro SET monto_actual=%s, monto_objetivo=%s WHERE id_meta=%s",
            (monto_actual, monto_objetivo, id_meta)
        )
    elif monto_actual is not None:
        cur.execute(
            "UPDATE metas_ahorro SET monto_actual=%s WHERE id_meta=%s",
            (monto_actual, id_meta)
        )
    elif monto_objetivo is not None:
        cur.execute(
            "UPDATE metas_ahorro SET monto_objetivo=%s WHERE id_meta=%s",
            (monto_objetivo, id_meta)
        )
    mysql.connection.commit()
    cur.close()
    return jsonify({"message": "Meta de ahorro actualizada exitosamente"})

@app.route('/goals/ahorro/<int:id_meta>', methods=['DELETE'])
def delete_ahorro_goal(id_meta):
    cur = mysql.connection.cursor()
    cur.execute("DELETE FROM metas_ahorro WHERE id_meta=%s", (id_meta,))
    mysql.connection.commit()
    cur.close()
    return jsonify({"message": "Meta de ahorro eliminada exitosamente"})

# ===========================
# METAS DE INVERSIÓN
# ===========================
@app.route('/goals/inversion/<int:id_user>', methods=['GET'])
def get_inversion_goals(id_user):
    cur = mysql.connection.cursor()
    cur.execute(
        "SELECT id_meta, descripcion, monto_objetivo, monto_actual FROM metas_inversion WHERE user_id=%s",
        (id_user,)
    )
    metas = cur.fetchall()
    cur.close()
    metas_list = [
        {
            "id_inversion": m[0],
            "nombre_meta": m[1],
            "monto_objetivo": float(m[2]),
            "monto_actual": float(m[3])
        } for m in metas
    ]
    return jsonify(metas_list)

@app.route('/goals/inversion', methods=['POST'])
def create_inversion_goal():
    data = request.get_json()
    user_id = data.get('id_user')
    nombre_meta = data.get('nombre_meta')
    monto_objetivo = data.get('monto_objetivo')

    if not all([user_id, nombre_meta, monto_objetivo]):
        return jsonify({"error": "Faltan datos"}), 400

    cur = mysql.connection.cursor()
    cur.execute(
        "INSERT INTO metas_inversion (user_id, descripcion, monto_objetivo) VALUES (%s, %s, %s)",
        (user_id, nombre_meta, monto_objetivo)
    )
    mysql.connection.commit()
    cur.close()
    return jsonify({"message": "Meta de inversión creada exitosamente"}), 201

@app.route('/goals/inversion/<int:id_meta>', methods=['PUT'])
def update_inversion_goal(id_meta):
    data = request.get_json()
    monto_actual = data.get('monto_actual')
    monto_objetivo = data.get('monto_objetivo')

    if monto_actual is None and monto_objetivo is None:
        return jsonify({"error": "No hay datos para actualizar"}), 400

    cur = mysql.connection.cursor()
    if monto_actual is not None and monto_objetivo is not None:
        cur.execute(
            "UPDATE metas_inversion SET monto_actual=%s, monto_objetivo=%s WHERE id_meta=%s",
            (monto_actual, monto_objetivo, id_meta)
        )
    elif monto_actual is not None:
        cur.execute(
            "UPDATE metas_inversion SET monto_actual=%s WHERE id_meta=%s",
            (monto_actual, id_meta)
        )
    elif monto_objetivo is not None:
        cur.execute(
            "UPDATE metas_inversion SET monto_objetivo=%s WHERE id_meta=%s",
            (monto_objetivo, id_meta)
        )
    mysql.connection.commit()
    cur.close()
    return jsonify({"message": "Meta de inversión actualizada exitosamente"})

@app.route('/goals/inversion/<int:id_meta>', methods=['DELETE'])
def delete_inversion_goal(id_meta):
    cur = mysql.connection.cursor()
    cur.execute("DELETE FROM metas_inversion WHERE id_meta=%s", (id_meta,))
    mysql.connection.commit()
    cur.close()
    return jsonify({"message": "Meta de inversión eliminada exitosamente"})

# ===========================
# IA - MASCOTA FINNY
# ===========================
def get_user_financial_context(id_user, username, cur):
    """
    Función auxiliar para recopilar datos clave de MySQL que la IA necesita.
    Esto minimiza el 'token' de entrada y mantiene la privacidad.
    """
    
    # 3.1. Obtener la Meta (si la tienes en la tabla 'users' o en otra tabla de metas)
    # COMENTARIO: Asegúrate de tener campos como 'meta_actual' y 'perfil_riesgo' en tu tabla 'users'
    # o una tabla separada de 'metas'.
    cur.execute("SELECT username, meta_actual, perfil_riesgo FROM users WHERE id_user=%s", (id_user,))
    user_info = cur.fetchone()
    user_context = {
        "nombre": username,
        "meta_actual": user_info[1] if user_info and len(user_info) > 1 else "Ninguna establecida",
        "perfil_riesgo": user_info[2] if user_info and len(user_info) > 2 else "Moderado"
    }

    # 3.2. Obtener Resumen de Ingresos y Egresos (últimos 30 días)
    fecha_inicio = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
    
    # Balance General (Ingresos vs. Egresos en los últimos 30 días)
    cur.execute(
        "SELECT tipo, SUM(monto) FROM movimientos WHERE user_id=%s AND fecha >= %s GROUP BY tipo",
        (id_user, fecha_inicio)
    )
    balance_data = dict(cur.fetchall())
    ingresos = float(balance_data.get('Ingreso', 0))
    egresos = float(balance_data.get('Egreso', 0))
    
    # Egresos por Categoría (los 3 principales)
    cur.execute(
        """
        SELECT categoria, SUM(monto) as total 
        FROM movimientos 
        WHERE user_id=%s AND tipo='Egreso' AND fecha >= %s
        GROUP BY categoria
        ORDER BY total DESC 
        LIMIT 3
        """,
        (id_user, fecha_inicio)
    )
    top_egresos = cur.fetchall()

    financial_summary = f"""
    - Período de análisis: Últimos 30 días.
    - Ingresos totales: ${ingresos:,.2f}
    - Egresos totales: ${egresos:,.2f}
    - Balance (Ingresos - Egresos): ${ingresos - egresos:,.2f}
    - 3 Categorías de Mayor Gasto: {', '.join([f'{cat}: ${monto:,.2f}' for cat, monto in top_egresos]) if top_egresos else 'No hay egresos recientes.'}
    """
    
    # Combinar todo en un contexto para la IA
    full_context = f"""
    Contexto del Usuario:
    Nombre: {user_context['nombre']}
    Meta Actual: {user_context['meta_actual']}
    Perfil de Riesgo (para consejos de inversión): {user_context['perfil_riesgo']}
    
    Resumen Financiero ({fecha_inicio} a hoy):
    {financial_summary}
    """
    return full_context

# 4. ENDPOINT PARA CHAT CON LA MASCOTA
@app.route('/ia/ask_mascot', methods=['POST'])
def ask_mascot_advisor():
    """
    Endpoint que recibe la pregunta del usuario, construye el prompt y llama a la IA.
    """
    data = request.get_json()
    id_user = data.get('id_user')
    username = data.get('username') # Debería venir del login
    user_prompt = data.get('prompt')
    
    if not all([id_user, username, user_prompt]):
        return jsonify({"error": "Faltan id_user, username o prompt"}), 400

    try:
        cur = mysql.connection.cursor()
        
        # 4.1. Recopilar datos financieros
        financial_context = get_user_financial_context(id_user, username, cur)
        cur.close()

        # 4.2. Crear el Prompt Maestro con la Personalidad de la Mascota
        # COMENTARIO: Aquí define el rol, tono y estilo de la mascota.
        MASCOTA_NOMBRE = "Finny, la ardilla" 
        
        system_instruction = f"""
        Eres {MASCOTA_NOMBRE}, el asesor financiero personal y la mascota de la app.
        Tu personalidad es: optimista, enérgica, un poco juguetona, y muy experta en finanzas.
        Tu tono es informal y motivador. **Usa emojis (💰, 📈, ✨) en tus respuestas para hacerlo más divertido.**
        Dirígete siempre al usuario por su nombre, {username}.
        
        Tu consejo debe basarse **estrictamente** en el contexto financiero proporcionado.
        NO compartas datos sensibles como montos exactos, solo usa el resumen para el consejo.
        
        Contexto Financiero para el análisis:
        {financial_context}
        
        Pregunta de {username}: {user_prompt}
        """

        # 4.3. Llamada a la API de Gemini
        # COMENTARIO: Asegúrate que el cliente y el modelo estén bien definidos
        
        response = client.models.generate_content(
            model=MODEL,
            contents=[system_instruction]
        )
        
        ia_advice = response.text

        # 4.4. Devolver la respuesta a Flutter
        return jsonify({
            "status": "success",
            "mascot_name": MASCOTA_NOMBRE,
            "advice": ia_advice
        })

    except APIError as e:
        # Esto captura errores si la clave API es incorrecta, hay límites excedidos, etc.
        print(f"Error de API de Gemini: {e}")
        return jsonify({"error": f"Error del servicio de IA: {e}"}), 500
    except Exception as e:
        # Esto captura errores de base de datos o lógica
        print(f"Error interno: {e}")
        return jsonify({"error": f"Error interno del servidor: {e}"}), 500


# ===========================
# RUN
# ===========================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
