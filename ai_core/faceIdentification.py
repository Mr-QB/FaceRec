import numpy as np
import os
from arcface import ArcFace
from configparser import ConfigParser
import pandas as pd
import joblib
from .setting import *
from .utility import *
from .setting import *

from .AntiSpoofing.antiSpoofing import AntiSpoofing
import pickle


class FaceIdentifier:
    def __init__(self):
        checkAndDownloaFile(ARCFACE_MODEL_PATH, ARCFACE_MODEL_URL)
        self.face_rec = ArcFace.ArcFace(ARCFACE_MODEL_PATH)
        self.threshold = FACE_VERIFY_THRESHOLD
        self.anti_spoofing = AntiSpoofing()
        self._loadModel()
        self.oc_lr_model_path = None

    def _loadModel(self):
        with open(LR_FACE_MODEL_PATH, "rb") as f:
            self.combined_model = pickle.load(f)
        self.lr_model = self.combined_model["model"]
        self.label_encoder = self.combined_model["label_encoder"]

    # Load an image and resize it
    def _embedImage(self, image: np.ndarray):
        emb1 = np.array(self.face_rec.calc_emb(image))
        return emb1.reshape(1, -1)

    def result_name(self, image):
        name = None
        # if self.anti_spoofing.check(image) == 0:
        if True:
            image_embedding = self._embedImage(image)

            proba = self.lr_model.predict_proba(image_embedding)[0]
            print(np.max(proba))
            if np.max(proba) < self.threshold:
                return "Unknown"
            else:
                name = self.lr_model.classes_[np.argmax(proba)]
                return self.label_encoder.inverse_transform([name])[0]

        else:
            return "Fake images"
