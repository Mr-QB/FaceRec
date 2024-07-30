import cv2
import math
from openvino.inference_engine import IECore
import numpy as np
from .setting import (
    MODEL_DETECT_FACE_XML,
    MODEL_DETECT_FACE_BIN,
    MODEL_FACE_ALIGNMENT_XML,
    MODEL_FACE_ALIGNMENT_BIN,
    SHAPE_OF_TRANSPOSE,
    CONF_FACE_DETECTION_THRESHOLD,
    FACE_SIZE,
    PI_TO_DEG,
)


class FaceDetector:

    def __init__(self) -> None:

        # Face detect
        ie = IECore()
        self.net_fd = ie.read_network(
            model=MODEL_DETECT_FACE_XML, weights=MODEL_DETECT_FACE_BIN
        )
        self.exec_net_fd = ie.load_network(network=self.net_fd, device_name="CPU")
        self.input_blob_fd = next(iter(self.net_fd.input_info))
        self.n_fd, self.c_fd, self.h_fd, self.w_fd = self.net_fd.input_info[
            self.input_blob_fd
        ].input_data.shape

        # Face Alignment
        self.net_fa = ie.read_network(
            model=MODEL_FACE_ALIGNMENT_XML, weights=MODEL_FACE_ALIGNMENT_BIN
        )
        self.exec_net_fa = ie.load_network(network=self.net_fa, device_name="CPU")
        self.input_blob_fa = next(iter(self.net_fa.input_info))
        self.n_fa, self.c_fa, self.h_fa, self.w_fa = self.net_fa.input_info[
            self.input_blob_fa
        ].input_data.shape

    def _getFaceAngle(self, image: np.ndarray):

        resized_image = cv2.resize(image, (self.w_fa, self.h_fa))
        resized_image = resized_image.transpose(SHAPE_OF_TRANSPOSE)
        # Change data layout from HWC to CHW
        input_data = np.expand_dims(resized_image, axis=0)

        # Run inference on the input image
        outputs = self.exec_net_fa.infer(inputs={self.input_blob_fa: input_data})
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

    def getFace(self, image: np.ndarray):
        resized_image = cv2.resize(image, (self.w_fd, self.h_fd))
        resized_image = resized_image.transpose(
            SHAPE_OF_TRANSPOSE
        )  # Change data layout from HWC to CHW
        input_data = np.expand_dims(resized_image, axis=0)
        imgs = []
        x = []
        y = []
        # Run inference on the input image
        outputs = self.exec_net_fd.infer(inputs={self.input_blob_fd: input_data})
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

    def getFaceAligneded(self, image: np.ndarray):
        faces_cropped, x, y = self.getFace(image)
        imgs = []
        x_aligneded = []
        y_aligneded = []
        for i in range(len(faces_cropped)):
            x_min, x_max = x[i]
            y_min, y_max = y[i]
            w = faces_cropped[i].shape[1] // 2
            h = faces_cropped[i].shape[0] // 2
            ymin = 0 if (y_min - h) < 0 else (y_min - h)
            xmin = 0 if (x_min - w) < 0 else (x_min - w)
            ymax = image.shape[0] if (y_max + h) > image.shape[0] else (y_max + h)
            xmax = image.shape[1] if (x_max + w) > image.shape[1] else (x_max + w)
            img_face_extend = image[ymin:ymax, xmin:xmax, :]

            alpha = self._getFaceAngle(faces_cropped[i])
            height, width = img_face_extend.shape[:2]
            center = (width / 2, height / 2)
            rotate_matrix = cv2.getRotationMatrix2D(center=center, angle=alpha, scale=1)
            img_face_extend_aligneded = cv2.warpAffine(
                src=img_face_extend, M=rotate_matrix, dsize=(width, height)
            )

            faces_cropped_, x_, y_ = self.getFace(img_face_extend_aligneded)
            if len(faces_cropped_) > 0:
                imgs.append(faces_cropped_[0])
                x_aligneded.append(x[0])
                y_aligneded.append(y[0])
        return imgs, x_aligneded, y_aligneded
