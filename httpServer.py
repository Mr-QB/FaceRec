from flask import Flask, request, jsonify
import base64
import os
import subprocess
import matplotlib.pyplot as plt
import numpy as np
from io import BytesIO

app = Flask(__name__)


def startTunnel():
    command = "autossh -M 0 -o ServerAliveInterval=60 -i ssh_key -R httptest.onlyfan.vn:80:localhost:5000 serveo.net"
    subprocess.Popen(command, shell=True)


@app.route("/pushimages", methods=["POST"])
def pushtest():
    data = request.json
    images = data.get("images", [])

    fig, axs = plt.subplots(1, len(images), figsize=(15, 5))
    if len(images) == 1:
        axs = [axs]

    for i, img_data in enumerate(images):
        img_bytes = base64.b64decode(img_data)
        img = plt.imread(BytesIO(img_bytes), format="PNG")

        axs[i].imshow(img)
        axs[i].axis("off")
        axs[i].set_title(f"Image {i}")

    plt.show()
    print(f"Received {len(images)} images")
    return jsonify({"status": "success", "message": "Images received"}), 200


# main driver function
if __name__ == "__main__":
    startTunnel()
    app.run(host="0.0.0.0")
