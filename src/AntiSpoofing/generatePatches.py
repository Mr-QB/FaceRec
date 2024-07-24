import cv2
import numpy as np

"""
Create patch from original input image by using bbox coordinate
"""
class CropImage:
    @staticmethod
    def _get_new_box(src_w, src_h, bbox, scale):
        x = bbox[0]
        y = bbox[1]
        box_w = bbox[2]
        box_h = bbox[3]

        scale = min((src_h-1)/box_h, min((src_w-1)/box_w, scale))

        new_width = box_w * scale
        new_height = box_h * scale
        center_x, center_y = box_w/2+x, box_h/2+y

        left_top_x = center_x-new_width/2
        left_top_y = center_y-new_height/2
        right_bottom_x = center_x+new_width/2
        right_bottom_y = center_y+new_height/2

        if left_top_x < 0:
            right_bottom_x -= left_top_x
            left_top_x = 0

        if left_top_y < 0:
            right_bottom_y -= left_top_y
            left_top_y = 0

        if right_bottom_x > src_w-1:
            left_top_x -= right_bottom_x-src_w+1
            right_bottom_x = src_w-1

        if right_bottom_y > src_h-1:
            left_top_y -= right_bottom_y-src_h+1
            right_bottom_y = src_h-1

        return int(left_top_x), int(left_top_y),\
               int(right_bottom_x), int(right_bottom_y)

    def crop(self, org_img,  scale, out_w, out_h, crop=True):
        if not crop:
            dst_img = cv2.resize(org_img, (out_w, out_h))
        else:
            src_h, src_w, _ = org_img.shape
            # Tính toán lại kích thước mới dựa trên tỷ lệ scale
            new_width = int(src_w * scale)
            new_height = int(src_h * scale)
            
            # Resize hình ảnh về kích thước mới
            dst_img = cv2.resize(org_img, (new_width, new_height))
            
            # Padding để đảm bảo kích thước đúng nếu cần
            pad_w = (out_w - new_width) // 2
            pad_h = (out_h - new_height) // 2

            if pad_w > 0 and pad_h > 0:
                dst_img = cv2.copyMakeBorder(dst_img, pad_h, pad_h, pad_w, pad_w, cv2.BORDER_CONSTANT, value=(0, 0, 0))
            
            # Resize lại về kích thước mong muốn nếu cần
            dst_img = cv2.resize(dst_img, (out_w, out_h))
        
        return dst_img
