from arcface import ArcFace

import pandas as pd
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import LabelEncoder
from ai_core.faceDetect import FaceDetector
from ai_core.setting import *
from .utility import *
import pickle


class Trainer:
    def __init__(self):
        checkAndDownloaFile(ARCFACE_MODEL_PATH, ARCFACE_MODEL_URL)
        self.face_rec = ArcFace.ArcFace(ARCFACE_MODEL_PATH)
        self.face_detector = FaceDetector()

        self._loadData()

    def _loadData(self):
        try:
            with open(FACEDATA100, "rb") as f:
                self.database = pickle.load(f)
            # self.face_data = pd.read_hdf("faceData/face_data.h5", key="df")
            # index_to_drop = self.face_data[self.face_data["label"] == "QBao"].index
            # self.face_data = self.face_data.drop(index_to_drop)
        except (FileNotFoundError, KeyError):
            self.database = pd.DataFrame(columns=["label", "embedding", "imageID"])

    def _saveData(self, lr_model, label_encoder):
        combined_model = {"model": lr_model, "label_encoder": label_encoder}
        with open(LR_FACE_MODEL_PATH, "wb") as f:
            pickle.dump(combined_model, f)

    def train(self):
        self._loadData()

        embeddings, labels = [], []

        for index, row in self.database.iterrows():
            if not row["incomplete"]:
                for embedding in row["arcfaceFeatures"]:
                    embeddings.append(embedding)
                    labels.append(row["fullName"])

        label_encoder = LabelEncoder()
        labels_encoded = label_encoder.fit_transform(labels)

        X = np.array(embeddings)
        y = np.array(labels_encoded)

        lr_model = make_pipeline(
            StandardScaler(),
            LogisticRegression(multi_class="multinomial", solver="lbfgs"),
        )
        lr_model.fit(X, y)

        self._saveData(lr_model, label_encoder)
        return True
