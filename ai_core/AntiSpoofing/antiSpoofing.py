import os
import cv2
import numpy as np
import argparse
import warnings
import time

import sys
from .utility import parseModelName
from .generatePatches import CropImage
from .antiSpoofPredict import AntiSpoofPredict


warnings.filterwarnings("ignore")


class AntiSpoofing:
    def __init__(self):
        self.model_test = AntiSpoofPredict(0)
        self.image_cropper = CropImage()
        self.model_dir = "src/AntiSpoofing/resources/anti_spoof_models"

    def check(self, image):
        prediction = np.zeros((1, 3))
        for model_name in os.listdir(self.model_dir):
            h_input, w_input, model_type, scale = parseModelName(model_name)
            param = {
                "org_img": image,
                "scale": scale,
                "out_w": w_input,
                "out_h": h_input,
                "crop": True,
            }
            if scale is None:
                param["crop"] = False
            image_converted = self.image_cropper.crop(**param)

            prediction += self.model_test.predict(
                image_converted, os.path.join(self.model_dir, model_name)
            )
        label = np.argmax(prediction)
        return label
