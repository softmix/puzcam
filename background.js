// background.js

let isRecording = false
let chunkCounter = 0

// Listen for messages from content scripts
browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.videoChunk) {
    chunkCounter++

    const url = new URL(sender.tab.url)
    const hostname = url.hostname.replace(/\./g, '-') // Replace dots with dashes
    const pathname = url.pathname.replace(/^\//, '') // Remove the leading slash
    const filename = `chunk_${chunkCounter}.webm` // Unique filename for each chunk

    fetch(message.videoChunk)
      .then(res => res.blob())
      .then(blob => {
        const url = URL.createObjectURL(blob)
        browser.downloads.download({
          url: url,
          filename: hostname + '/' + pathname + '/' + filename
        })
      })
  }
})

// Function to send a message to the content script
function sendMessageToContentScript(tabId, message) {
  browser.tabs.sendMessage(tabId, message)
}

// Listener for browser action click to start/stop recording
browser.browserAction.onClicked.addListener((tab) => {
  console.log("Clicked")
  isRecording = !isRecording
  updateIcon()

  const command = isRecording ? "startRecording" : "stopRecording"
  console.log("Sending command: " + command)
  sendMessageToContentScript(tab.id, { command: command })
})

// Function to update the browser action icon
function updateIcon() {
  const iconPath = isRecording ? "recording.svg" : "not_recording.svg"
  browser.browserAction.setIcon({ path: iconPath })
}
