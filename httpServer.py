from flask import Flask, request, jsonify
import base64
import subprocess
import numpy as np
import cv2
from src.trainer import Trainer


class FlaskApp:
    def __init__(self):
        self.app = Flask(__name__)
        self.UPLOAD_FOLDER = "uploads"
        self._setupRoutes()
        self.trainer = Trainer()
        self.face_data = []

    def _startTunnel(self):
        # command = "autossh -M 0 -o ServerAliveInterval=60 -i ssh_key -R httptest.onlyfan.vn:80:localhost:5000 serveo.net"
        command = "autossh -M 0 -o ServerAliveInterval=60  -N -R  5001:localhost:5001 ubuntu@54.252.209.12 -i ec2_key.pem"
        subprocess.Popen(command, shell=True)

    def _loadImageFromBytes(self, image_bytes):
        np_array = np.frombuffer(image_bytes, np.uint8)
        image = cv2.imdecode(np_array, cv2.IMREAD_COLOR)
        if image is None:
            raise ValueError(
                "Image could not be decoded. Check if the image bytes are correct."
            )

        return image

    def _setupRoutes(self):
        @self.app.route("/status", methods=["GET"])
        def status():
            return "Running..."

        @self.app.route("/pushimages", methods=["POST"])
        def pushtest():
            data = request.json
            images = data.get("images", [])
            user_name = data.get("userName", "unknown")

            for i, img_data in enumerate(images):
                img_bytes = base64.b64decode(img_data)
                image = self._loadImageFromBytes(img_bytes)
                print("image: ", i)

                if not self.trainer.addNewData(user_name, image):
                    return (
                        jsonify(
                            {
                                "status": "false",
                                "message": "Face cannot be detected in the image",
                            }
                        ),
                        201,
                    )

                # Display image

            return jsonify({"status": "success", "message": "Images received"}), 200

    def run(self):
        self._startTunnel()
        self.app.run(host="0.0.0.0", port=5001)


# main driver function
if __name__ == "__main__":
    my_app = FlaskApp()
    my_app.run()
