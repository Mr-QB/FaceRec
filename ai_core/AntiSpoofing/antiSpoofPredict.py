import os
import torch
import numpy as np
import torch.nn.functional as F


from .utility import getKernel, parseModelName
from .model_lib.MiniFASNet import (
    MiniFASNetV1,
    MiniFASNetV2,
    MiniFASNetV1SE,
    MiniFASNetV2SE,
)
from .data_io import transform as trans

MODEL_MAPPING = {
    "MiniFASNetV1": MiniFASNetV1,
    "MiniFASNetV2": MiniFASNetV2,
    "MiniFASNetV1SE": MiniFASNetV1SE,
    "MiniFASNetV2SE": MiniFASNetV2SE,
}


class AntiSpoofPredict:
    def __init__(self, device_id):
        self.device = torch.device(
            "cuda:{}".format(device_id) if torch.cuda.is_available() else "cpu"
        )

    def _load_model(self, model_path):
        # Load model
        model_name = os.path.basename(model_path)
        h_input, w_input, model_type, _ = parseModelName(model_name)
        self.kernel_size = getKernel(
            h_input,
            w_input,
        )
        self.model = MODEL_MAPPING[model_type](conv6_kernel=self.kernel_size).to(
            self.device
        )

        # Load model weights
        state_dict = torch.load(model_path, map_location=self.device)
        if next(iter(state_dict)).startswith("module."):
            state_dict = {
                k[7:]: v for k, v in state_dict.items()
            }  # Remove 'module.' prefix if present
        self.model.load_state_dict(state_dict)

    def predict(self, img, model_path):

        # Transform and prepare image for prediction
        test_transform = trans.Compose(
            [
                trans.ToTensor(),
            ]
        )
        img_tensor = test_transform(img)
        img_tensor = img_tensor.unsqueeze(0).to(self.device)

        # Load model and perform inference
        self._load_model(model_path)
        self.model.eval()
        with torch.no_grad():
            result = self.model.forward(img_tensor)
            result = F.softmax(result).cpu().numpy()
        return result

    def crop_image(self, org_img, bbox):
        x, y, w, h = bbox
        img_cropped = org_img[y : y + h, x : x + w]
        return img_cropped
