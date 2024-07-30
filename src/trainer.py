from arcface import ArcFace
import os
import cv2
import pandas as pd
import numpy as np
from sklearn import svm
import joblib
from sklearn.preprocessing import LabelEncoder
from src.faceDetect import FaceDetector
from src.setting import *
from .utility import checkAndDownloaFile
import pickle


class Trainer:
    def __init__(self):
        checkAndDownloaFile(ARCFACE_MODEL_PATH, ARCFACE_MODEL_URL)
        self.face_rec = ArcFace.ArcFace(ARCFACE_MODEL_PATH)
        self.face_detector = FaceDetector()

        self._loadData()

    def _embebdding(self, image):
        faces_cropped, x, y = self.face_detector.detect_face(image)
        if len(faces_cropped) > 0:
            return self.face_rec.calc_emb(faces_cropped[0])
        else:
            return False

    def _loadData(self):
        try:
            with open(FACEDATA, "rb") as f:
                self.face_data = pickle.load(f)
            # self.face_data = pd.read_hdf("faceData/face_data.h5", key="df")
            # index_to_drop = self.face_data[self.face_data["label"] == "QBao"].index
            # self.face_data = self.face_data.drop(index_to_drop)
        except (FileNotFoundError, KeyError):
            self.face_data = pd.DataFrame(columns=["label", "embedding", "imageID"])

    def clear(self):
        self._loadData()

    def addNewData(self, label, image, image_id):
        face_embedding = self._embebdding(image)
        if not isinstance(face_embedding, bool):
            if "imageID" not in self.face_data.columns:
                self.face_data["imageID"] = pd.Series(dtype="str")
            if not self.face_data["imageID"].isin([image_id]).any():
                new_row = {
                    "label": label,
                    "embedding": face_embedding,
                    "imageID": image_id,
                }
                self.face_data = self.face_data._append(new_row, ignore_index=True)
            else:
                return False
            return True
        else:
            return False

    def _saveData(self, svm_model, label_encoder, oc_svm_model):
        with open(FACEDATA, "wb") as f:
            pickle.dump(self.face_data, f)
        combined_model = {"model": svm_model, "label_encoder": label_encoder}
        with open(SVM_FACE_MODEL_PATH, "wb") as f:
            pickle.dump(combined_model, f)
        with open(OC_SVM_FACE_MODEL_PATH, "wb") as f:
            pickle.dump(oc_svm_model, f)

    def train(self):
        embeddings = (
            self.face_data["embedding"].apply(lambda x: np.array(x).flatten()).tolist()
        )
        labels = self.face_data["label"].tolist()
        print(labels)

        label_encoder = LabelEncoder()
        labels_encoded = label_encoder.fit_transform(labels)

        X = np.array(embeddings)
        y = np.array(labels_encoded)

        svm_model = svm.SVC(kernel="linear", probability=True)
        svm_model.fit(X, y)

        oc_svm_model = svm.OneClassSVM(kernel="linear", gamma="auto", nu=0.01)
        oc_svm_model.fit(X)

        self.combined_model = {"model": svm_model, "label_encoder": label_encoder}

        self._saveData(svm_model, label_encoder, oc_svm_model)
        return True
