from flask import Flask, request, jsonify
import numpy as np
import cv2
import time

import psutil

pid = psutil.Process().pid
process = psutil.Process(pid)

app = Flask(__name__)


def rotate_image(image, angle):
    (h, w) = image.shape[:2]
    center = (w // 2, h // 2)
    rotation_matrix = cv2.getRotationMatrix2D(center, angle, 1.0)

    # Tính kích thước mới của hình ảnh
    abs_cos = abs(rotation_matrix[0, 0])
    abs_sin = abs(rotation_matrix[0, 1])

    # Tính kích thước mới của hình ảnh sau khi xoay
    new_w = int(h * abs_sin + w * abs_cos)
    new_h = int(h * abs_cos + w * abs_sin)

    # Cập nhật ma trận xoay với kích thước mới
    rotation_matrix[0, 2] += (new_w / 2) - center[0]
    rotation_matrix[1, 2] += (new_h / 2) - center[1]

    rotated_image = cv2.warpAffine(image, rotation_matrix, (new_w, new_h))
    return rotated_image


@app.route("/pushimages", methods=["POST"])
def upload():
    try:
        start_time = time.time()

        image_bytes = request.stream.read()

        height = 320
        width = 240
        np_img = (
            np.frombuffer(image_bytes, dtype=np.uint8)
            .reshape((height, width, 1))
            .copy()
        )

        rotated_image = cv2.flip(np_img, 1)
        rotated_image = rotate_image(rotated_image, -90)
        cv2.imwrite("received_image_rotated.png", rotated_image)
        cv2.imwrite("received_image.png", np_img)

        # image = cv2.putText(np_img, 'OpenCV', (50, 50), cv2.FONT_HERSHEY_SIMPLEX,
        #            1, (255, 0, 0), 2, cv2.LINE_AA)

        elapsed_time = time.time() - start_time
        print("processing_time_ms:", elapsed_time * 1000)
        # CPU %
        # cpu_percent = process.cpu_percent(interval=1)

        # # RAM
        # memory_info = process.memory_info()

        # print(f"CPU Percent: {cpu_percent}%")
        # print(f"Memory Usage: {memory_info.rss / (1024 * 1024):.2f} MB")  # in MB

        return (
            jsonify(
                {
                    "message": "Image received successfully",
                    "processing_time_ms": elapsed_time * 1000,
                }
            ),
            200,
        )
    except Exception as e:
        print(str(e))
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, threaded=True)
