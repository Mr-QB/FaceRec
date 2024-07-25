from arcface import ArcFace
import os
import cv2
import pandas as pd
import numpy as np
from sklearn import svm
import joblib
from sklearn.preprocessing import LabelEncoder
from src.faceDetect import FaceDetector
from .utility import checkAndDownloaFile
from src.setting import *


class Trainer:
    def __init__(self):
        checkAndDownloaFile(ARCFACE_MODEL_PATH, ARCFACE_MODEL_URL)
        self.face_rec = ArcFace.ArcFace(ARCFACE_MODEL_PATH)
        self.face_data_path = FACEDATA
        self.face_detector = FaceDetector()

        self._loadData()

    def _embebdding(self, image):
        faces_cropped, x, y = self.face_detector.detect_face(image)
        if len(faces_cropped) > 0:
            return self.face_rec.calc_emb(faces_cropped[0])
        else:
            return False

    def _loadData(self):
        self.face_data = pd.read_hdf(self.face_data_path, key="df")

    def addNewData(self, label, image):
        face_embedding = self._embebdding(image)
        if face_embedding:
            new_row = {"label": label, "embedding": face_embedding}
            self.face_data = self.face_data._append(new_row, ignore_index=True)
        else:
            return False

    def _saveData(self):
        self.face_data.to_hdf(self.face_data_path, key="df", mode="w")
        joblib.dump(self.combined_model, SVM_FACE_MODEL_PATH)

    def train(self):
        embeddings = (
            self.face_data["embedding"]
            .apply(lambda x: np.fromstring(x[1:-1], sep=","))
            .tolist()
        )
        labels = self.face_data["label"].tolist()

        label_encoder = LabelEncoder()
        labels_encoded = label_encoder.fit_transform(labels)

        X = np.array(embeddings)
        y = np.array(labels_encoded)

        model = svm.SVC(kernel="linear", probability=True)
        model.fit(X, y)

        self.combined_model = {"model": model, "label_encoder": label_encoder}
