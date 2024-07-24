from flask import Flask, request, jsonify
import base64
import os
import subprocess
from io import BytesIO
from IPython.display import display, Image

app = Flask(__name__)

UPLOAD_FOLDER = "uploads"


def startTunnel():
    command = "autossh -M 0 -o ServerAliveInterval=60 -i ssh_key -R httptest.onlyfan.vn:80:localhost:5000 serveo.net"
    subprocess.Popen(command, shell=True)


@app.route("/pushimages", methods=["POST"])
def pushtest():
    data = request.json
    images = data.get("images", [])

    if not os.path.exists(UPLOAD_FOLDER):
        os.makedirs(UPLOAD_FOLDER)

    for i, img_data in enumerate(images):
        img_bytes = base64.b64decode(img_data)

        # Save image to file
        file_path = os.path.join(UPLOAD_FOLDER, f"image_{i}.png")
        with open(file_path, "wb") as img_file:
            img_file.write(img_bytes)

        # Display image
        display(Image(data=img_bytes, format="png"))

    print(f"Received {len(images)} images")
    return jsonify({"status": "success", "message": "Images received"}), 200


# main driver function
if __name__ == "__main__":
    startTunnel()
    app.run(host="0.0.0.0")
