import './style.css'
document.querySelector<HTMLDivElement>('#app')!.innerHTML = `
<div class="element"></div>
`
import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Collaboration from '@tiptap/extension-collaboration'
import CollaborationCursor from "@tiptap/extension-collaboration-cursor";
import * as Y from "yjs";
import { IndexeddbPersistence } from 'y-indexeddb'
import { fromUint8Array, toUint8Array } from 'js-base64'

import * as awarenessProtocol from 'y-protocols/awareness.js'

const colours = ["#ffa5a5", "#f9ffa5", "#a9ffa5", "#a5e8ff", "#dfa5ff"];
const MY_COLOR = colours[Math.floor(Math.random() * colours.length)];
let document_name = "my-document_name"
const yDoc = new Y.Doc();
let awareness = new awarenessProtocol.Awareness(yDoc)

// const Docsource = new EventSource('/doc');
// Docsource.onmessage = (event) => {
//     const binaryEncoded = toUint8Array(event.data)
//     Y.applyUpdate(yDoc, binaryEncoded)
// };


let provider = new IndexeddbPersistence(document_name, yDoc)
//@ts-ignore
provider.awareness = awareness

// Create and maintain a persistent WebSocket connection
const webSocket = new WebSocket("ws://" + location.host + "/ws");

// Event listener for WebSocket open event
webSocket.onopen = (event) => {
    console.log("WebSocket connection established");
};
webSocket.onmessage = function (event) {
    console.log(event.data + " WebSocket message recived");

    const binaryEncoded = toUint8Array(event.data)
    //@ts-ignore
    Y.applyUpdate(yDoc, binaryEncoded)
};

// Event listener for WebSocket error event
webSocket.onerror = (error) => {
    console.error("WebSocket error:", error);
};

// Event listener for WebSocket close event
webSocket.onclose = (event) => {
    console.log("WebSocket connection closed:", event);
};

// Set up the awareness update listener
yDoc.on("update", doc => {
    const documentState = Y.encodeStateAsUpdate(yDoc) // is a Uint8Array
    const binaryEncoded = fromUint8Array(documentState)

    if (webSocket.readyState === WebSocket.OPEN) {
        // Send the encoded awareness update to the WebSocket server
        webSocket.send(binaryEncoded);
    } else {
        console.warn("WebSocket is not open. Update not sent.");
    }
});


// awareness.on('update', ({ added, updated, removed }) => {
//     const webSocket = new WebSocket(
//         "ws://" + location.host + "/ws"
//     );

//     webSocket.onopen = (event) => {
//         webSocket.send("ping")
//     };
//     const changedClients = added.concat(updated).concat(removed)
//     let body = awarenessProtocol.encodeAwarenessUpdate(awareness, changedClients)
//     // fetch('/awareness', { method: 'POST', body });
// })


// const AwarenessSource = new EventSource('/awareness');
// AwarenessSource.onmessage = (event) => {
//     const binaryEncoded = toUint8Array(event.data)
//     //@ts-ignore
//     awarenessProtocol.applyAwarenessUpdate(provider.awareness, binaryEncoded, "")
// };


// yDoc.on("update", doc => {
//     const documentState = Y.encodeStateAsUpdate(yDoc) // is a Uint8Array
//     let body = documentState
//     // fetch('/doc', { method: 'POST', body });
// })


const editor = new Editor({
    element: document.querySelector('.element')!,
    extensions: [StarterKit.configure({
        history: false, // Disables default history to use Collaboration's history management
    }),

    Collaboration.configure({
        document: yDoc, // Configure Y.Doc for collaboration
    }),
    CollaborationCursor.configure({
        provider: provider,
        user: {
            name: "cutie_number" + Math.floor(Math.random() * 20),
            color: MY_COLOR,
        },
    }),
    ],

})


