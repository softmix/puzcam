// content.js

let mediaRecorder

// Function to start recording
function startRecording() {
    const originalCanvas = document.getElementById('canvas')
    if (!originalCanvas) {
        console.error("Canvas not found")
        return
    }

    // Create an off-screen canvas with a smaller resolution
    let scale = 1
    const maxDimension = Math.max(originalCanvas.width, originalCanvas.height)
    if (maxDimension > 720) {
        scale = 720 / maxDimension
    }

    console.log("Recording at scale: " + scale)

    const offScreenCanvas = document.createElement('canvas')
    offScreenCanvas.width = originalCanvas.width * scale
    offScreenCanvas.height = originalCanvas.height * scale

    const offScreenContext = offScreenCanvas.getContext('2d')

    // Function to draw the scaled image to the off-screen canvas
    function drawScaled() {
        offScreenContext.drawImage(originalCanvas, 0, 0, offScreenCanvas.width, offScreenCanvas.height)
    }

    const stream = offScreenCanvas.captureStream(25)
    //const options = { mimeType: 'video/webm; codecs=vp8', bitsPerSecond: 1000000 }
    const options = { mimeType: 'video/webm' }
    mediaRecorder = new MediaRecorder(stream, options)

    mediaRecorder.ondataavailable = function (event) {
        if (event.data.size > 0) {
            sendVideoChunkToBackground(event.data)
        }
    }

    mediaRecorder.onstop = function () {
        console.log("Recording stopped. All chunks handled.")
        // Any additional cleanup or UI update can go here
    }

    mediaRecorder.start(10000)

    function updateCanvas() {
        drawScaled()
        requestAnimationFrame(updateCanvas)
    }

    updateCanvas()
}

// Function to send the video chunk to the background script
function sendVideoChunkToBackground(chunk) {
    const reader = new FileReader()
    reader.readAsDataURL(chunk)
    reader.onloadend = function () {
        const base64data = reader.result
        browser.runtime.sendMessage({ videoChunk: base64data })
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
