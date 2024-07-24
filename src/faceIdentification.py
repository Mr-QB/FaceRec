import numpy as np
import os
from arcface import ArcFace
from configparser import ConfigParser
from .setting import *
import pandas as pd
from .utility import *
from .setting import *
from .AntiSpoofing.antiSpoofing import AntiSpoofing


class FaceIdentifier:
    def __init__(self):
        checkAndDownloaFile(ARCFACE_MODEL_PATH, ARCFACE_MODEL_URL)
        self.face_rec = ArcFace.ArcFace(ARCFACE_MODEL_PATH)
        self.data_face = pd.read_hdf("faceData/face_data.h5", "df")
        self.threshold = FACE_VERIFY_THRESHOLD
        self.anti_spoofing = AntiSpoofing()

    # Load an image and resize it
    def embedImage(self, image: np.ndarray):
        emb1 = self.face_rec.calc_emb(image)
        return emb1

    def result_name(self, image):
        if self.anti_spoofing.check(image) == 0:
            # if True:
            distance_old = MAXIMUM_DISTANCE
            image_embedding = self.embedImage(image)
            name = None
            for index, row in self.data_face.iterrows():
                distance = calculateEuclide(
                    np.array(image_embedding), np.array(row["embedding"])
                )
                if abs(distance) <= distance_old and distance < self.threshold:
                    distance_old = distance
                    name = row["label"]

            if name is not None:
                return name
            return "Unable to identify"
        else:
            return "Fake images"
