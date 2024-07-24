import math
import cv2
import numpy as np
from openvino.inference_engine import IECore
from .setting import (
    MODEL_FACE_ALIGNMENT_XML,
    MODEL_FACE_ALIGNMENT_BIN,
    FACE_SIZE,
    PI_TO_DEG,
    SHAPE_OF_TRANSPOSE,
)
import copy


class FaceAlignment:

    def __init__(self) -> None:
        self.model_xml = MODEL_FACE_ALIGNMENT_XML
        self.model_bin = MODEL_FACE_ALIGNMENT_BIN

        ie = IECore()
        self.net = ie.read_network(model=self.model_xml, weights=self.model_bin)
        self.exec_net = ie.load_network(network=self.net, device_name="CPU")
        self.input_blob = next(iter(self.net.input_info))
        self.n, self.c, self.h, self.w = self.net.input_info[
            self.input_blob
        ].input_data.shape

    def align_face(self, image: np.ndarray):

        resized_image = cv2.resize(image, (self.w, self.h))
        resized_image = resized_image.transpose(SHAPE_OF_TRANSPOSE)
        # Change data layout from HWC to CHW
        input_data = np.expand_dims(resized_image, axis=0)

        # Run inference on the input image
        outputs = self.exec_net.infer(inputs={self.input_blob: input_data})
        output_blob = next(iter(outputs))
        output_data = outputs[output_blob][0]
        x1, y1 = output_data[6:8]
        x1 = x1 * image.shape[1]
        y1 = y1 * image.shape[0]

        x0, y0 = output_data[2:4]
        x0 = x0 * image.shape[1]
        y0 = y0 * image.shape[0]
        a = abs(y1 - y0)
        b = abs(x1 - x0)
        c = math.sqrt(a * a + b * b)
        cos_alpha = (b * b + c * c - a * a) / (2 * b * c)
        alpha = np.arccos(cos_alpha)
        sign = np.sign(y1 - y0)
        alpha = sign * alpha * PI_TO_DEG / math.pi

        return alpha
