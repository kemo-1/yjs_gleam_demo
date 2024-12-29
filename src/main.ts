import './style.css'

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

render()
function render() {



    if (localStorage.getItem("name") === null) {
        document.querySelector<HTMLDivElement>('#app')!.innerHTML =
            ` 
    <div class="name-page" >
        <form id="nameForm">
            <label for="name">Enter your name:</label>
            <input type="text" id="name" name="name" required />
            <button type="submit">Join Room</button>
        </form>
    </div>
  
`;

        const form = document.querySelector<HTMLFormElement>('#nameForm');

        form?.addEventListener('submit', (event) => {
            event.preventDefault(); // Prevent page reload
            const nameInput = document.querySelector<HTMLInputElement>('#name');
            const name = nameInput?.value;

            if (name) {
                localStorage.setItem('name', name); // Save name to localStorage
                render()
            }
        });

    } else {
        document.querySelector<HTMLDivElement>('#app')!.innerHTML =
            `
    <div class="element"></div>
    `


        let provider = new IndexeddbPersistence(document_name, yDoc)
        //@ts-ignore
        provider.awareness = awareness

        // Create and maintain a persistent WebSocket connection
        const DocSocket = new WebSocket("ws://" + location.host + "/doc");
        const AwarenessSocket = new WebSocket("ws://" + location.host + "/awareness");

        // Event listener for WebSocket open event
        DocSocket.onopen = (event) => {
            // console.log("DocSocket connection established");
        };
        AwarenessSocket.onopen = (event) => {
            // console.log("AwarenessSocket connection established");
        };
        DocSocket.onmessage = function (event) {
            // console.log(event.data + "DocSocket message recived");

            const binaryEncoded = toUint8Array(event.data)
            //@ts-ignore
            Y.applyUpdate(yDoc, binaryEncoded)
        };
        AwarenessSocket.onmessage = function (event) {
            // console.log(event.data + "AwarenessSocket message recived");

            const binaryEncoded = toUint8Array(event.data)
            //@ts-ignore
            awarenessProtocol.applyAwarenessUpdate(provider.awareness, binaryEncoded, "")


        };
        // Event listener for WebSocket error event
        DocSocket.onerror = (error) => {
            // console.error("DocSocket error:", error);
        };
        AwarenessSocket.onerror = (error) => {
            // console.error("AwarenessSocket error:", error);
        };

        // Event listener for WebSocket close event
        DocSocket.onclose = (event) => {
            // console.log("DocSocket connection closed:", event);
        };
        AwarenessSocket.onclose = (event) => {
            // console.log("AwarenessSocket connection closed:", event);
        };

        // Set up the awareness update listener
        yDoc.on("update", doc => {
            const documentState = Y.encodeStateAsUpdate(yDoc) // is a Uint8Array
            const binaryEncoded = fromUint8Array(documentState)

            if (DocSocket.readyState === WebSocket.OPEN) {
                // Send the encoded awareness update to the WebSocket server
                DocSocket.send(binaryEncoded);
            } else {
                console.warn("DocSocket is not open. Update not sent.");
            }
        });

        awareness.on('update', ({ added, updated, removed }) => {

            const changedClients = added.concat(updated).concat(removed)
            let documentAwareness = awarenessProtocol.encodeAwarenessUpdate(awareness, changedClients)
            const binaryEncoded = fromUint8Array(documentAwareness)

            if (AwarenessSocket.readyState === WebSocket.OPEN) {
                // Send the encoded awareness update to the WebSocket server
                AwarenessSocket.send(binaryEncoded);
            } else {
                console.warn("AwarenessSocket is not open. Update not sent.");
            }

        })


        // const AwarenessSource = new EventSource('/awareness');



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
                    name: localStorage.getItem("name"),
                    color: MY_COLOR,
                },
            }),
            ],

        })




    }


}