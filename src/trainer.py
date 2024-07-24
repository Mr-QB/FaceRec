from arcface import ArcFace
from .utility import checkAndDownloaFile
import os
from src.setting import *
import cv2
import pandas as pd
from src.faceDetect import FaceDetector


class Trainer:
    def __init__(self):
        checkAndDownloaFile(ARCFACE_MODEL_PATH, ARCFACE_MODEL_URL)
        self.face_rec = ArcFace.ArcFace(ARCFACE_MODEL_PATH)
        self.folder_data = FOLDERDATA
        self.face_detector = FaceDetector()

    def train(self):
        self.face_data = []

        for filename in os.listdir(self.folder_data):
            file_path = os.path.join(self.folder_data, filename)
            image = cv2.imread(file_path)
            faces_cropped, x, y = self.face_detector.detect_face(image)
            if faces_cropped is not None:
                emb1 = self.face_rec.calc_emb(faces_cropped)
                label = os.path.splitext(filename)[0]
                self.face_data.append([label, emb1])
        self.face_data = pd.DataFrame(self.face_data, columns=["label", "embedding"])
        self.face_data.to_hdf("faceData/face_data.h5", key="df", mode="w")
