from arcface import ArcFace
import numpy as np

from ai_core.faceDetect import FaceDetector
from ai_core.utility import checkAndDownloaFile
from ai_core.setting import ARCFACE_MODEL_PATH, ARCFACE_MODEL_URL


class Extractor:
    def __init__(self):
        checkAndDownloaFile(ARCFACE_MODEL_PATH, ARCFACE_MODEL_URL)
        self.face_rec = ArcFace.ArcFace(ARCFACE_MODEL_PATH)
        self.face_detector = FaceDetector()

    def featureEmbedding(self, image_faces):
        embeddings = []
        for image in image_faces:
            embeddings.append(self.face_rec.calc_emb(np.copy(image)))
        return embeddings
