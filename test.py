# import the Flask library
from flask import Flask, render_template, request
import subprocess


def startTunnel():
    command = "autossh -M 0 -o ServerAliveInterval=60 -i ssh_key -R httptest.onlyfan.vn:80:localhost:5000 serveo.net"
    subprocess.Popen(command, shell=True)


app = Flask(__name__)


@app.route("/")
def hello_world():
    return "Hello World"


# main driver function
if __name__ == "__main__":

    startTunnel()
    app.run(host="0.0.0.0")
