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
import { WebrtcProvider } from 'y-webrtc'
import { fromUint8Array, toUint8Array } from 'js-base64'

// 5 nice colors
const colours = ["#ffa5a5", "#f9ffa5", "#a9ffa5", "#a5e8ff", "#dfa5ff"];

// Pick a random color from the list
// This is just for demonstration purposes
const MY_COLOR = colours[Math.floor(Math.random() * colours.length)];

let document_name = "my-document_name"

const yDoc = new Y.Doc();
// const provider = new WebrtcProvider(document_name, yDoc, { maxConns: 70 + Math.floor(Math.random() * 70) })
// const provider = new YPartyKitProvider(
//   "localhost:1999",
//   document_name,
//   yDoc
// );
const Docsource = new EventSource('/doc');
Docsource.onmessage = (event) => {
    const binaryEncoded = toUint8Array(event.data)
    Y.applyUpdate(yDoc, binaryEncoded)
};
import * as awarenessProtocol from 'y-protocols/awareness.js'
let awareness = new awarenessProtocol.Awareness(yDoc)

let provider = new IndexeddbPersistence(document_name, yDoc)
//@ts-ignore
provider.awareness = awareness


awareness.on('change', ({ added, updated, removed }) => {
    const changedClients = added.concat(updated).concat(removed)
    let body = awarenessProtocol.encodeAwarenessUpdate(awareness, changedClients)
    console.log(body)
    fetch('/awareness', { method: 'POST', body });

})
awareness.on('update', ({ added, updated, removed }) => {
    const changedClients = added.concat(updated).concat(removed)
    let body = awarenessProtocol.encodeAwarenessUpdate(awareness, changedClients)
    console.log(body)
    fetch('/awareness', { method: 'POST', body });

})
const AwarenessSource = new EventSource('/awareness');
AwarenessSource.onmessage = (event) => {
    const binaryEncoded = toUint8Array(event.data)
    //@ts-ignore
    awarenessProtocol.applyAwarenessUpdate(provider.awareness, binaryEncoded, "")
};
yDoc.on("update", doc => {
    const documentState = Y.encodeStateAsUpdate(yDoc) // is a Uint8Array
    // Transform Uint8Array to a Base64-String

    const base64Encoded = fromUint8Array(documentState)

    // Transform Base64-String back to an Uint8Array
    const binaryEncoded = toUint8Array(base64Encoded)
    let body = documentState
    fetch('/doc', { method: 'POST', body });
})
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


