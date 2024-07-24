import cv2
from openvino.inference_engine import IECore
import numpy as np
from .setting import (
    MODEL_DETECT_FACE_XML,
    MODEL_DETECT_FACE_BIN,
    SHAPE_OF_TRANSPOSE,
    CONF_FACE_DETECTION_THRESHOLD,
    FACE_SIZE,
)


class FaceDetector:

    def __init__(self) -> None:
        self.model_xml = MODEL_DETECT_FACE_XML
        self.model_bin = MODEL_DETECT_FACE_BIN

        ie = IECore()
        self.net = ie.read_network(model=self.model_xml, weights=self.model_bin)
        self.exec_net = ie.load_network(network=self.net, device_name="CPU")
        self.input_blob = next(iter(self.net.input_info))
        self.n, self.c, self.h, self.w = self.net.input_info[
            self.input_blob
        ].input_data.shape

    def detect_face(self, image: np.ndarray):
        resized_image = cv2.resize(image, (self.w, self.h))
        resized_image = resized_image.transpose(
            SHAPE_OF_TRANSPOSE
        )  # Change data layout from HWC to CHW
        input_data = np.expand_dims(resized_image, axis=0)
        imgs = []
        x = []
        y = []
        # Run inference on the input image
        outputs = self.exec_net.infer(inputs={self.input_blob: input_data})
        output_blob = next(iter(outputs))
        output_data = outputs[output_blob][0][0]
        for detection in output_data:
            confidence = detection[2]
            if confidence > CONF_FACE_DETECTION_THRESHOLD:
                x_min, y_min, x_max, y_max = detection[3:7]
                x_min = abs(int(x_min * image.shape[1]))
                y_min = abs(int(y_min * image.shape[0]))
                x_max = int(x_max * image.shape[1])
                y_max = int(y_max * image.shape[0])
                x.append([x_min, x_max])
                y.append([y_min, y_max])

                img = image[y_min:y_max, x_min:x_max, :]
                img = cv2.resize(img, (FACE_SIZE, FACE_SIZE))
                imgs.append(img)
        return imgs, x, y
