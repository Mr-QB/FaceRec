from flask import Flask, request, jsonify
import base64
import os
import subprocess


def startTunnel():
    command = "autossh -M 0 -o ServerAliveInterval=60 -i ssh_key -R httptest.onlyfan.vn:80:localhost:5000 serveo.net"
    subprocess.Popen(command, shell=True)


app = Flask(__name__)


@app.route("/")
def hello_world():
    return "Hello World"


@app.route("/pushtest", methods=["POST"])
def pushtest():
    data = request.json
    images = data.get("images", [])

    if not os.path.exists("uploads"):
        os.makedirs("uploads")

    for i, img_data in enumerate(images):
        img_bytes = base64.b64decode(img_data)
        with open(f"uploads/image_{i}.png", "wb") as img_file:
            img_file.write(img_bytes)

    print(f"Received {len(images)} images")
    return jsonify({"status": "success", "message": "Images received"}), 200


# main driver function
if __name__ == "__main__":

    startTunnel()
    app.run(host="0.0.0.0")
