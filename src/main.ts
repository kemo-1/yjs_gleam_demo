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
const provider = new WebrtcProvider(document_name, yDoc, { maxConns: 70 + Math.floor(Math.random() * 70) })
// const provider = new YPartyKitProvider(
//   "localhost:1999",
//   document_name,
//   yDoc
// );
const source = new EventSource('/sse');
source.onmessage = (event) => {

    // console.log("yo are you getting this", event.data);
    const binaryEncoded = toUint8Array(event.data)
    Y.applyUpdate(yDoc, binaryEncoded)

};
new IndexeddbPersistence(document_name, yDoc)

yDoc.on("update", doc => {
    const documentState = Y.encodeStateAsUpdate(yDoc) // is a Uint8Array
    // Transform Uint8Array to a Base64-String
    console.log("documentState", documentState)
    const base64Encoded = fromUint8Array(documentState)
    console.log("base64Encoded", base64Encoded)

    // Transform Base64-String back to an Uint8Array
    const binaryEncoded = toUint8Array(base64Encoded)
    let body = documentState
    fetch('/post', { method: 'POST', body });
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


