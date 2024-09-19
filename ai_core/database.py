import pandas as pd
import pickle
import numpy as np

from ai_core.setting import *
from ai_core.extractor import Extractor


class HrmDatabase:
    def __init__(self):
        self.data_structures = [
            "fullName",
            "email",
            "userID",
            "images",
            "arcfaceFeatures",
            "incomplete",
        ]

        self.database = self._loadData()
        self.arcface_extractor = Extractor()
        self.changed = False
        self.new_data = False

    def _loadData(self):
        try:
            with open(DATABASE, "rb") as f:
                database = pickle.load(f)
        except (FileNotFoundError, KeyError):
            database = pd.DataFrame(columns=self.data_structures)
        return database

    def addNew(self, data_batch):
        if data_batch["userID"] in self.database["userID"].values:
            return True

        complete_data = {
            col: data_batch.get(col, np.nan) for col in self.data_structures
        }
        complete_data["arcfaceFeatures"] = self.arcface_extractor.featureEmbedding(
            complete_data["images"]
        )
        if len(complete_data["arcfaceFeatures"]) < NUMBER_POSE_HEAD:
            complete_data["incomplete"] = True

        else:
            self.new_data = True
            complete_data["incomplete"] = False

        new_row_dt = pd.DataFrame([complete_data])
        self.database = pd.concat([self.database, new_row_dt], ignore_index=True)
        self._saveData()

    def deleteData(self, deletion_item):
        self.changed = True
        if deletion_item in self.database["userID"].values:
            self.database = self.database[self.database["userID"] != deletion_item]
            self._saveData()
            return True
        return False

    def changeData(self, data_batch, change_type):
        if data_batch["userID"] in self.database["userID"].values:
            index = self.database[
                self.database["userID"] == data_batch["userID"]
            ].index[0]
            user_row_data = self.database.loc[index]

            complete_data = {
                col: data_batch.get(col, np.nan) for col in self.data_structures
            }
            complete_data["arcfaceFeatures"] = self.arcface_extractor.featureEmbedding(
                complete_data["images"]
            )

            if change_type == "add":

                user_row_data["images"] = (
                    user_row_data["images"] + complete_data["images"]
                )
                user_row_data["arcfaceFeatures"] = (
                    user_row_data["arcfaceFeatures"] + complete_data["arcfaceFeatures"]
                )
                self.database.loc[index] = user_row_data
            elif change_type == "replace":

                for key, value in complete_data.items():
                    self.database.at[index, key] = value

            self.database.at[index, "incomplete"] = (
                len(self.database.loc[index]["arcfaceFeatures"]) < NUMBER_POSE_HEAD
            )
            self.new_data = ~self.database.at[index, "incomplete"]

            self._saveData()

        else:
            return False

    def _saveData(self):
        with open(DATABASE, "wb") as data_file:
            pickle.dump(self.database, data_file)
