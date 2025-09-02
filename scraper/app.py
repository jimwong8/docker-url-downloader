from flask import Flask, request, jsonify
from playwright.sync_api import sync_playwright

app = Flask(__name__)

@app.route("/scrape", methods=["POST"])
def scrape():
    url = request.json["url"]
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.goto(url)
        real_url = page.url
        browser.close()
    return jsonify({"real_url": real_url})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8500)