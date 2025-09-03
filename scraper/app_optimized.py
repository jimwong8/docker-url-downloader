# 导入路径设置 (仅用于开发环境IDE支持)
try:
    import setup_path  # 本地开发环境路径设置
except ImportError:
    pass  # 在Docker容器中忽略

from flask import Flask, request, jsonify
import requests
from urllib.parse import urljoin, urlparse
import time

app = Flask(__name__)

@app.route("/scrape", methods=["POST"])
def scrape():
    url = request.json["url"]
    try:
        # 使用requests获取最终重定向URL
        response = requests.head(url, allow_redirects=True, timeout=10)
        real_url = response.url
        
        # 如果HEAD请求失败，尝试GET请求
        if not real_url or real_url == url:
            response = requests.get(url, allow_redirects=True, timeout=10, stream=True)
            real_url = response.url
            
        return jsonify({"real_url": real_url, "status": "success"})
        
    except requests.RequestException as e:
        return jsonify({"real_url": url, "status": "error", "message": str(e)})

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "service": "scraper-optimized"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8500)
