from flask import Flask, request, jsonify
import cv2
import numpy as np
import base64
from io import BytesIO
from PIL import Image, ExifTags


app = Flask(__name__)


def _adjustImageOrientation(image, orientation):
    try:
        # for orientation in ExifTags.TAGS.keys():
        #     if ExifTags.TAGS[orientation] == "Orientation":
        #         break

        # if "exif" in image.info:
        #     exif = image._getexif()

        # if exif is not None:
        #     orientation = exif.get(orientation)
        #     print(orientation)
        return image.rotate(orientation, expand=True)
        if orientation == 90:
            image = image.rotate(90, expand=True)
        elif orientation == 6:
            image = image.rotate(180, expand=True)
        elif orientation == 8:
            image = image.rotate(270, expand=True)
    except Exception as e:
        print(f"Error adjusting image orientation: {e}")

    return image


@app.route("/recogn", methods=["POST"])
def upload_image():
    try:
        data = request.get_json()
        base64_image = data.get("image")
        orientation = data.get("orientation")
        print(orientation)

        if not base64_image:
            return jsonify({"error": "No image data provided"}), 400

        image_data = base64.b64decode(base64_image)
        image = Image.open(BytesIO(image_data))
        image = _adjustImageOrientation(image, 90 - orientation)
        image_np = np.array(image)
        image_cv = cv2.cvtColor(image_np, cv2.COLOR_RGB2BGR)
        cv2.imwrite("uploaded_image.jpg", image_cv)

        return jsonify({"message": "Image received and processed successfully"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(debug=True)
