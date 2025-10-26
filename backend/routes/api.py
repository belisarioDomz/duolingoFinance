from flask import Blueprint, jsonify, request

api = Blueprint('api', __name__)

@api.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    user = data.get('username')
    password = data.get('password')

    if user == 'admin' and password == '1234':
        return jsonify({"status": "ok", "token": "abc123"}), 200
    else:
        return jsonify({"status": "error"}), 401