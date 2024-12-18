// import gleam from "vite-gleam";

import { defineConfig } from "vite"

import { viteSingleFile } from "vite-plugin-singlefile"

export default defineConfig({
    plugins: [viteSingleFile()],
}) 