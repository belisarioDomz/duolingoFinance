from flask import Flask, request, jsonify
from flask_mysqldb import MySQL
from flask_bcrypt import Bcrypt
from dotenv import load_dotenv
import os
from datetime import datetime, timedelta

# -------------------- IMPORTACIÓN DE LA IA --------------------
# 1. Asegúrate de instalar: pip install google-genai
from google import genai
from google.genai.errors import APIError 
# --------------------------------------------------------------

load_dotenv()

app = Flask(__name__)

# -------------------- Configuración DB --------------------
app.config['MYSQL_HOST'] = os.getenv('DB_HOST')
app.config['MYSQL_USER'] = os.getenv('DB_USER')
app.config['MYSQL_PASSWORD'] = os.getenv('DB_PASSWORD')
app.config['MYSQL_DB'] = os.getenv('DB_NAME')

mysql = MySQL(app)
bcrypt = Bcrypt(app)

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

# =========================================================================================
# (Tus funciones existentes de /register, /login, /movements, etc. van aquí arriba...)
# =========================================================================================

# [Aquí van las demás rutas de tu código, como register, login, movements, etc.]


# --------------------------------------------------------------------------
# NUEVA SECCIÓN: ASESOR CON IA (LA MASCOTA)
# --------------------------------------------------------------------------

# 3. FUNCIONES DE LÓGICA DE IA (PREPARACIÓN DE DATOS)
# ---------------------------------------------------
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
# --------------------------------------
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