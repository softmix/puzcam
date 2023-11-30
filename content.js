// content.js

let mediaRecorder
let recordedChunks = []

// Function to start recording
function startRecording() {
    const canvas = document.getElementById('canvas')
    if (!canvas) {
        console.error("Canvas not found")
        return
    }

    const stream = canvas.captureStream(25)
    const options = { mimeType: 'video/webm; codecs=vp8', bitsPerSecond: 1000000 }
    mediaRecorder = new MediaRecorder(stream, options)

    mediaRecorder.ondataavailable = function (event) {
        if (event.data.size > 0) {
            recordedChunks.push(event.data)
        }
    }

    mediaRecorder.onstop = sendVideoToBackground
    mediaRecorder.start()
}

// Function to send the recorded video to the background script
function sendVideoToBackground() {
    const blob = new Blob(recordedChunks, { type: 'video/webm' })
    const reader = new FileReader()
    reader.readAsDataURL(blob)
    reader.onloadend = function () {
        const base64data = reader.result
        browser.runtime.sendMessage({ videoData: base64data })
    }
}

// Listen for messages from the background script to start/stop recording
browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.command === "startRecording") {
        console.log("Start recording")
        startRecording()
    } else if (message.command === "stopRecording") {
        console.log("Stop recording")
        if (mediaRecorder && mediaRecorder.state === "recording") {
            mediaRecorder.stop()
        }
    }
})
