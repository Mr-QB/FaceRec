import cv2
import time

from src.faceDetect import FaceDetector
from src.faceIdentification import FaceIdentifier

# from src.faceAlignMent import FaceAlignment


def rotateImage90Counterclockwise(image):
    rotated_image = cv2.transpose(image)
    rotated_image = cv2.flip(rotated_image, flipCode=0)
    return rotated_image


def main():

    video = cv2.VideoCapture(0)
    face_detector = FaceDetector()  # Create Face detector
    # face_alignment = FaceAlignment()
    face_identifier = FaceIdentifier()

    # Initialize variables for FPS calculation
    prev_frame_time = time.time()
    while True:
        ret, frame = video.read()
        fps = 0
        if not ret:
            break

        frame = rotateImage90Counterclockwise(frame)

        # Perform face detection and identification
        # faces_cropped, x, y = face_detector.getFaceAligneded(frame)
        faces_cropped, x, y = face_detector.getFaceAligneded(frame)

        for i in range(len(faces_cropped)):
            x_min, x_max = x[i]
            y_min, y_max = y[i]

            # face_name = face_identifier.result_name(faces_cropped[i])
            #             # cv2.imshow("face", faces_cropped_[0])

            cv2.rectangle(frame, (x_min, y_min), (x_max, y_max), (0, 255, 0), 1)
            # cv2.putText(
            #     frame,
            #     face_name,
            #     (x_min, y_min),
            #     cv2.FONT_HERSHEY_SIMPLEX,
            #     0.7,
            #     (255, 0, 0),
            #     2,
            # )

        #   Calculate FPS
        new_frame_time = time.time()
        fps = 1 / (new_frame_time - prev_frame_time)
        prev_frame_time = new_frame_time

        cv2.putText(
            frame,
            f"FPS: {fps:.2f}",
            (10, 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            (255, 0, 0),
            2,
        )

        # Display the frame
        cv2.imshow("frame", frame)

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break


if __name__ == "__main__":
    main()
