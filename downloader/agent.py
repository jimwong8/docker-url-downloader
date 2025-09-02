import os
import time
import threading
import requests

NAME = os.getenv("NAME", "unnamed")
SERVER = os.getenv("SERVER", "http://resolver:8000")

def register():
    try:
        requests.post(f"{SERVER}/register", json={"name": NAME})
        print(f"[{NAME}] Registered.")
    except Exception as e:
        print(f"[{NAME}] Registration failed: {e}")

def heartbeat():
    while True:
        try:
            requests.post(f"{SERVER}/heartbeat", json={"name": NAME})
        except Exception as e:
            print(f"[{NAME}] Heartbeat failed: {e}")
        time.sleep(30)

def fetch_and_download():
    while True:
        try:
            res = requests.get(f"{SERVER}/task/{NAME}")
            if res.status_code == 200 and res.json():
                task = res.json()
                url = task.get("url")
                filename = url.split("/")[-1]
                print(f"[{NAME}] Downloading: {url}")
                r = requests.get(url, stream=True)
                with open(filename, "wb") as f:
                    for chunk in r.iter_content(chunk_size=8192):
                        f.write(chunk)
                print(f"[{NAME}] Download complete: {filename}")
        except Exception as e:
            print(f"[{NAME}] Download error: {e}")
        time.sleep(10)

if __name__ == "__main__":
    register()
    threading.Thread(target=heartbeat).start()
    fetch_and_download()