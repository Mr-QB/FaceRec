import time
from flask import Flask, request, jsonify
import base64
from io import BytesIO
from PIL import Image, ExifTags
from threading import Timer
import subprocess
import numpy as np
import cv2

from ai_core.trainer import Trainer
from ai_core.faceDetect import FaceDetector
from ai_core.faceIdentification import FaceIdentifier
from ai_core.database import HrmDatabase

# from ai_core.utility import checkImage


class FlaskApp:
    def __init__(self):
        self.app = Flask(__name__)
        self._setupRoutes()
        self.trainer = Trainer()
        self.face_detector = FaceDetector()  # Create Face detector
        self.face_identifier = FaceIdentifier()
        self.database = HrmDatabase()

    def trainning(self):
        self.trainer.train()

    def _faceRecogn(self, image):
        names = []
        faces_cropped, x, y = self.face_detector.getFaceAligneded(image)
        for i in range(len(faces_cropped)):
            x_min, x_max = x[i]
            y_min, y_max = y[i]

            face_name = self.face_identifier.result_name(faces_cropped[i])
            names.append(face_name)
        return names

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

        @self.app.route("/user", methods=["POST"])
        def addUser():
            request_data = request.get_json()
            images = request_data.get("images", {})
            user_id = request_data.get("userID", "unknown")
            user_name = request_data.get("userName", "unknown")

            for instruction, base64_image in images.items():
                image_bytes = base64.b64decode(base64_image)
                image_array = np.frombuffer(image_bytes, dtype=np.uint8)
                image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)

                if image is not None:
                    rotated_image = cv2.flip(image, 1)
                    faces_cropped, x, y = self.face_detector.getFaceAligneded(
                        rotated_image
                    )
                    if len(faces_cropped)
                    cv2.imwrite(f"image/{instruction}.png", faces_cropped[0])
                else:
                    raise ValueError("Failed to decode image")

            try:
                #     img_bytes = base64.b64decode(image_data)
                #     image = self._loadImageFromBytes(img_bytes)
                #     cv2.imwrite("image1.png", image)

                #     data_batch = {
                #         "fullName": user_name,
                #         "userID": user_id,
                #         "email": "david@example.com",
                #         "Images": image_data,
                #         "incomplete": True,
                #     }

                #     self.database.addNew(data_batch=data_batch)

                return jsonify({"status": "success", "message": "Image received"}), 200
            except Exception as e:
                print(f"Error: {e}")
                return jsonify({"status": "false", "message": str(e)}), 500

        @self.app.route("/user/:id", methods=["POST"])
        def changeUserData():

            data = request.json
            image_data = data.get("images", "")
            user_id = data.get("userID", "unknown")
            user_name = data.get("userName", "unknown")
            change_type = data.get("type", "unknown")

            if not image_data:
                return (
                    jsonify({"status": "false", "message": "No image data provided"}),
                    400,
                )

            try:
                img_bytes = base64.b64decode(image_data)
                image = self._loadImageFromBytes(img_bytes)
                cv2.imwrite("image1.png", image)

                data_batch = {
                    "userID": user_id,
                    "fullName": user_name,
                    "email": "david@example.com",
                    "Images": image_data,
                    "incomplete": True,
                }

                self.database.changeData(data_batch=data_batch, change_type=change_type)

                return jsonify({"status": "success", "message": "Image received"}), 200
            except Exception as e:
                print(f"Error: {e}")
                return jsonify({"status": "false", "message": str(e)}), 500

        @self.app.route("/delete", methods=["POST"])
        def deleteUserData():
            try:
                data = request.json
                user_id = data.get("userID", "unknown")

                self.database.deleteData(user_id)

                return jsonify({"status": "success", "message": "Image received"}), 200
            except Exception as e:
                print(f"Error: {e}")
                return jsonify({"status": "false", "message": str(e)}), 500

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
                print(e)
                return jsonify({"error": str(e)}), 500

    def run(self):
        self.app.run(host="0.0.0.0", port=5000)


# main driver function
if __name__ == "__main__":
    my_app = FlaskApp()
    my_app.run()
