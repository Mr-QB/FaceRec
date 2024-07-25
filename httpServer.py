from flask import Flask, request, jsonify
import base64
import os
import subprocess
from io import BytesIO
from src.trainer import Trainer


class FlaskApp:
    def __init__(self):
        self.app = Flask(__name__)
        self.UPLOAD_FOLDER = "uploads"
        self.setup_routes()
        self.trainer = Trainer()
        self.face_data = []

    def start_tunnel(self):
        # command = "autossh -M 0 -o ServerAliveInterval=60 -i ssh_key -R httptest.onlyfan.vn:80:localhost:5000 serveo.net"
        command = "autossh -M 0 -o ServerAliveInterval=60  -N -R  5001:localhost:5001 ubuntu@54.252.209.12 -i ec2_key.pem"
        subprocess.Popen(command, shell=True)

    def setup_routes(self):
        @self.app.route("/status", methods=["GET"])
        def status():
            return "Running"

        @self.app.route("/pushimages", methods=["POST"])
        def pushtest():
            data = request.json
            images = data.get("images", [])
            user_name = data.get("userName", "unknown")

            if not os.path.exists(self.UPLOAD_FOLDER):
                os.makedirs(self.UPLOAD_FOLDER)

            for i, img_data in enumerate(images):
                img_bytes = base64.b64decode(img_data)

                if not self.trainer.addNewData(user_name, img_bytes):
                    return (
                        jsonify(
                            {
                                "status": "false",
                                "message": "Face cannot be detected in the image",
                            }
                        ),
                        200,
                    )

                # Display image

            return jsonify({"status": "success", "message": "Images received"}), 200

    def run(self):
        self.start_tunnel()
        self.app.run(host="0.0.0.0", port=5001)


# main driver function
if __name__ == "__main__":
    my_app = FlaskApp()
    my_app.run()
