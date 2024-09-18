# Face Recognition App

This face recognition app uses technology to identify faces in images and perform actions based on face angles.

## Installation

1. **Clone the Repository**

   ```bash
   git clone https://github.com/your-username/face-recognition-app.git
   cd face-recognition-app
   ```

2. **Install Dependencies**

   Install the required packages using pip:

   ```bash
   pip install -r requirements.txt
   ```

## Start the Server

To start the server, run:

   ```bash
   python httpServer.py
   ```

The server will run at `http://localhost:5000`.

Or Colab server path: [in here](https://colab.research.google.com/drive/1s58wcY4QF_y-kH2SDcofV5v9o3GNJMTz?usp=sharing)

### Add & Update

```@startuml
participant MobileApp
participant FaceDetectionService as Server
database "Server database" as database

skin rose

MobileApp -> Server: POST /user

Server -> Server: Check image valid

Server -> database: save patch data

Server -> MobileApp: return {missingImages: listString}

MobileApp ->Server: POST /updateUser 

Server -> Server: Check image valid

Server -> database: Update/add patch database

Server -> MobileApp: return {missingImages: listString}

Server -> Server: check logic of database (updated & no incomplete data) -> TRUE

Server -> Server: Tranning new model

Server -> database: Save database

@enduml```


### Delete
```
@startuml
participant MobileApp
participant FaceDetectionService as Server
database "Server database" as database

skin rose

MobileApp -> Server: POST /delete

Server -> database: Detele info of user

Server -> Server: Tranning new model

Server -> database: Save database

@enduml
```

### Recogn

```
@startuml
participant MobileApp
participant FaceDetectionService as Server
database "Server database" as database

skin rose

MobileApp -> Server: POST /recogn

Server -> database: Detele info of user

Server -> Server: Load model & predict

Server -> MobileApp: return result

@enduml
```