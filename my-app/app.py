#!/usr/bin/env python3
import os
import socket
from flask import Flask, jsonify, make_response

app = Flask(__name__)


APP_NAME = os.getenv('APP_NAME', 'app')
POD_NAME = os.getenv('POD_NAME', socket.gethostname())
NODE_NAME = os.getenv('NODE_NAME', 'unknown')

@app.route('/')
def hello():
    html = f'''
<!DOCTYPE html>
<html>
<head>
  <title>Hello Kubernetes! - Version 2</title>
  <style>
    body {{
      font-family: 'Ubuntu', sans-serif;
      background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
    }}
    .main {{
      background: white;
      border-radius: 20px;
      padding: 40px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      text-align: center;
      max-width: 500px;
      
      animation: fadeIn 0.5s ease-in;
    }}
    
    @keyframes fadeIn {{
      from {{
        opacity: 0;
        transform: translateY(20px);
      }}
      to {{
        opacity: 1;
        transform: translateY(0);
      }}
    }}
    img {{
      width: 100px;
      margin-bottom: 20px;
      /* V2: Added hover effect */
      transition: transform 0.3s ease;
    }}
    img:hover {{
      transform: scale(1.1);
    }}
    .content {{
      text-align: left;
    }}
    #message {{
      font-size: 24px;
      color: #333;
      margin-bottom: 20px;
      text-align: center;
      position: relative;
    }}
  
    .version-badge {{
      display: inline-block;
      background: #f5576c;
      color: white;
      font-size: 12px;
      padding: 2px 8px;
      border-radius: 20px;
      margin-left: 10px;
      vertical-align: middle;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
    }}
    th {{
      text-align: right;
      padding: 8px;
      
      
      
      
      color: #666;
    }}
    td {{
      text-align: left;
      padding: 8px;
      color: #333;
      font-weight: bold;
    }}
    
    .footer {{
      margin-top: 20px;
      font-size: 12px;
      color: #999;
      text-align: center;
      border-top: 1px solid #eee;
      padding-top: 15px;
    }}
  </style>
  <link href="https://fonts.googleapis.com/css?family=Ubuntu:300" rel="stylesheet">
</head>
<body>
  <div class="main">
    <img src="https://raw.githubusercontent.com/kubernetes/kubernetes/master/logo/logo.png"/>
    <div class="content">
      <div id="message">
        Hello from {APP_NAME}! <span class="version-badge">v2</span>
      </div>
      <div id="info">
        <table>
          <tr>
            <th>pod:</th>
            <td>{POD_NAME}</td>
          </tr>
          <tr>
            <th>node:</th>
            <td>{NODE_NAME}</td>
          </tr>
          <tr>
            <th>version:</th>
            <td>v2.0.0</td>
          </tr>
        </table>
      </div>
      <div class="footer">
        Powered by Argo CD GitOps | Auto-deployed from GitHub
      </div>
    </div>
  </div>
</body>
</html>
    '''
    response = make_response(html)
    response.headers['Content-Type'] = 'text/html'
    return response

@app.route('/api')
def api():
    return jsonify({
        'status': 'ok',
        'message': f'Hello from {APP_NAME} (v2)',
        'pod': POD_NAME,
        'node': NODE_NAME,
        'version': 'v2.0.0'
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8888)