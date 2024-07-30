import numpy as np
import os
from arcface import ArcFace
from configparser import ConfigParser
import pandas as pd
import joblib
from .setting import *
from .utility import *
from .setting import *

# from .AntiSpoofing.antiSpoofing import AntiSpoofing
import pickle


class FaceIdentifier:
    def __init__(self):
        checkAndDownloaFile(ARCFACE_MODEL_PATH, ARCFACE_MODEL_URL)
        self.face_rec = ArcFace.ArcFace(ARCFACE_MODEL_PATH)
        self.data_face = pd.read_hdf("faceData/face_data.h5", "df")
        self.threshold = FACE_VERIFY_THRESHOLD
        # self.anti_spoofing = AntiSpoofing()
        self._loadModel()
        self.oc_svm_model_path = None

    def _loadModel(self):
        with open(SVM_FACE_MODEL_PATH, "rb") as f:
            self.combined_model = pickle.load(f)
        self.svm_model = self.combined_model["model"]
        self.label_encoder = self.combined_model["label_encoder"]
        with open(OC_SVM_FACE_MODEL_PATH, "rb") as f:
            self.oc_svm_model = pickle.load(f)

    # Load an image and resize it
    def _embedImage(self, image: np.ndarray):
        emb1 = np.array(self.face_rec.calc_emb(image))
        return emb1.reshape(1, -1)

    def result_name(self, image):
        name = None
        # if self.anti_spoofing.check(image) == 0:
        if True:
            image_embedding = self._embedImage(image)
            # Check if the image is an outlier using OneClassSVM
            is_outlier = self.oc_svm_model.predict(image_embedding)
            if is_outlier == -1:  # -1 indicates anomaly in OneClassSVM
                return "Anomaly detected"

            name = self.svm_model.predict(image_embedding)
            name = self.label_encoder.inverse_transform(name)[0]

            # if name is not None:
            return name
            # return "Unable to identify"
        else:
            return "Fake images"
