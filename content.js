// content.js

let mediaRecorder

function findBlackRectangle(originalCanvas) {
    // Create a temporary canvas
    const tempCanvas = document.createElement('canvas')
    tempCanvas.width = originalCanvas.width
    tempCanvas.height = originalCanvas.height

    // Get the context of the temporary canvas
    const ctx = tempCanvas.getContext('2d')
    if (!ctx) {
        console.error("Cannot get context of temporary canvas")
        return null
    }

    // Draw the original canvas content onto the temporary canvas
    ctx.drawImage(originalCanvas, 0, 0)

    // Now proceed with the same pixel analysis as before
    const imageData = ctx.getImageData(0, 0, tempCanvas.width, tempCanvas.height)
    const data = imageData.data

    let minX = tempCanvas.width, minY = tempCanvas.height, maxX = 0, maxY = 0

    function isBlack(x, y) {
        const index = (y * tempCanvas.width + x) * 4
        return data[index] < 30 && data[index + 1] < 30 && data[index + 2] < 30 // Check if pixel is black
    }

    // Scan from top
    top_scan: for (let y = 0; y < tempCanvas.height; y++) {
        for (let x = 0; x < tempCanvas.width; x++) {
            if (isBlack(x, y)) {
                minY = y
                break top_scan
            }
        }
    }

    // Scan from bottom
    bottom_scan: for (let y = tempCanvas.height - 1; y >= minY; y--) {
        for (let x = 0; x < tempCanvas.width; x++) {
            if (isBlack(x, y)) {
                maxY = y
                break bottom_scan
            }
        }
    }

    // Scan from left
    left_scan: for (let x = 0; x < tempCanvas.width; x++) {
        for (let y = minY; y <= maxY; y++) {
            if (isBlack(x, y)) {
                minX = x
                break left_scan
            }
        }
    }

    // Scan from right
    right_scan: for (let x = tempCanvas.width - 1; x >= minX; x--) {
        for (let y = minY; y <= maxY; y++) {
            if (isBlack(x, y)) {
                maxX = x
                break right_scan
            }
        }
    }

    return {
        x: minX,
        y: minY,
        width: maxX - minX + 1,
        height: maxY - minY + 1
    }
}

// Function to start recording
function startRecording() {
    const scaledRecording = false

    if (mediaRecorder && mediaRecorder.state === "recording") {
        console.log("Already recording")
        return
    }

    // Find the original canvas
    const originalCanvas = document.getElementById('canvas')
    if (!originalCanvas) {
        console.error("Canvas not found")
        return
    }

    // Find the black rectangle
    const blackRectangle = findBlackRectangle(originalCanvas)

    // Use the dimensions and position of the black rectangle
    const contentX = blackRectangle.x
    const contentY = blackRectangle.y
    const contentWidth = blackRectangle.width
    const contentHeight = blackRectangle.height

    let stream
    if (scaledRecording) {
        // Create an off-screen canvas with a smaller resolution
        let scale = 1
        const maxDimension = Math.max(originalCanvas.width, originalCanvas.height)
        if (maxDimension > 720) {
            scale = 720 / maxDimension
        }

        console.log("Recording at scale: " + scale)

        const offScreenCanvas = document.createElement('canvas')
        offScreenCanvas.width = contentWidth * scale
        offScreenCanvas.height = contentHeight * scale

        const offScreenContext = offScreenCanvas.getContext('2d')

        // Function to draw the scaled image to the off-screen canvas
        function drawScaled() {
            offScreenContext.drawImage(originalCanvas, contentX, contentY, contentWidth, contentHeight, 0, 0, offScreenCanvas.width, offScreenCanvas.height)
        }

        stream = offScreenCanvas.captureStream(25)
    } else {
        stream = originalCanvas.captureStream(25)
    }

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

    if (scaledRecording) {
        function updateCanvas() {
            drawScaled()
            requestAnimationFrame(updateCanvas)
        }

        updateCanvas()
    }
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
