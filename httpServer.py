import time
from flask import Flask, request, jsonify
import base64
from io import BytesIO
from PIL import Image, ExifTags
from threading import Timer
import subprocess
import numpy as np
import cv2

from src.trainer import Trainer
from src.faceDetect import FaceDetector
from src.faceIdentification import FaceIdentifier


class FlaskApp:
    def __init__(self):
        self.app = Flask(__name__)
        self._setupRoutes()
        # self.trainer = Trainer()
        self.last_request_time = time.time()
        self.inactivity_timeout = 60
        self.inactivity_timer = Timer(self.inactivity_timeout, self.clear)
        self.inactivity_timer.start()
        self.face_detector = FaceDetector()  # Create Face detector
        self.face_identifier = FaceIdentifier()

    def _adjustImageOrientation(self, image):
        try:
            # Kiểm tra và điều chỉnh hướng của ảnh
            for orientation in ExifTags.TAGS.keys():
                if ExifTags.TAGS[orientation] == "Orientation":
                    break

            if "exif" in image.info:
                exif = image._getexif()
                if exif is not None:
                    orientation = exif.get(orientation)
                    if orientation == 3:
                        image = image.rotate(180, expand=True)
                    elif orientation == 6:
                        image = image.rotate(270, expand=True)
                    elif orientation == 8:
                        image = image.rotate(90, expand=True)
        except Exception as e:
            print(f"Error adjusting image orientation: {e}")

        return image

    def _faceRecogn(self, image):
        names = []
        faces_cropped, x, y = self.face_detector.getFaceAligneded(image)
        for i in range(len(faces_cropped)):
            x_min, x_max = x[i]
            y_min, y_max = y[i]

            face_name = self.face_identifier.result_name(faces_cropped[i])
            names.append(face_name)
        return face_name

    def _startTunnel(self):
        command = "autossh -M 0 -o ServerAliveInterval=60 -i ssh_key -R httptest.onlyfan.vn:80:localhost:5000 serveo.net"
        # command = "autossh -M 0 -o ServerAliveInterval=60  -N -R  5001:localhost:5001 ubuntu@54.252.209.12 -i ec2_key.pem"
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
        @self.app.route("/", methods=["GET"])
        def home():
            return "Welcome to the server!"

        @self.app.route("/pushimages", methods=["POST"])
        def pushtest():
            self.last_request_time = time.time()
            self.reset_inactivity_timer()

            data = request.json
            image_data = data.get("images", "")
            user_name = data.get("userName", "unknown")
            image_id = data.get("imageID", "unknown")
            print(image_id)

            if not image_data:
                return (
                    jsonify({"status": "false", "message": "No image data provided"}),
                    400,
                )

            try:
                img_bytes = base64.b64decode(image_data)
                image = self._loadImageFromBytes(img_bytes)

                if not self.trainer.addNewData(user_name, image, image_id):
                    return (
                        jsonify(
                            {
                                "status": "false",
                                "message": "Face cannot be detected in the image",
                            }
                        ),
                        400,
                    )

                return jsonify({"status": "success", "message": "Image received"}), 200
            except Exception as e:
                print(f"Error: {e}")
                return jsonify({"status": "false", "message": str(e)}), 500

        @self.app.route("/trainning", methods=["POST"])
        def trainningSvmModel():
            data = request.json
            if data.get("status", False):
                self.trainer.train()
                return (
                    jsonify({"status": "success", "message": "Successful training"}),
                    200,
                )

        @self.app.route("/recogn", methods=["POST"])
        def recognFace():
            try:
                data = request.get_json()
                base64_image = data.get("image")

                if not base64_image:
                    return jsonify({"error": "No image data provided"}), 400

                image_data = base64.b64decode(base64_image)
                image = Image.open(BytesIO(image_data))
                image = self._adjustImageOrientation(image)
                image_np = np.array(image)
                image_cv = cv2.cvtColor(image_np, cv2.COLOR_RGB2BGR)
                cv2.imwrite("uploaded_image.jpg", image_cv)

                names = self._faceRecogn(image_cv)
                print(names)

                return (
                    jsonify({"message": "Image successfully uploaded", "names": names}),
                    200,
                )
            except Exception as e:
                return jsonify({"error": str(e)}), 500

    def clear(self):
        print("Clearing data due to inactivity...")
        self.trainer.clear()

    def reset_inactivity_timer(self):
        if self.inactivity_timer.is_alive():
            self.inactivity_timer.cancel()
        self.inactivity_timer = Timer(self.inactivity_timeout, self.clear)
        self.inactivity_timer.start()

    def run(self):
        self._startTunnel()
        self.app.run(host="0.0.0.0", port=5000)


# main driver function
if __name__ == "__main__":
    my_app = FlaskApp()
    my_app.run()
