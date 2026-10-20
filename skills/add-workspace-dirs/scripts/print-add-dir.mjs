#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const usage = "usage: print-add-dir.mjs <workspace-file> [--have <dir>]...";

main();

function main() {
  const { workspaceFile, have } = parseArgs(process.argv.slice(2));
  const workspacePath = path.resolve(workspaceFile);
  const document = readWorkspace(workspacePath);
  const folders = document.folders;
  if (!Array.isArray(folders) || folders.length === 0) {
    console.error("error: workspace file has no folders");
    process.exit(1);
  }

  const baseDir = path.dirname(workspacePath);
  const present = new Set(
    [process.cwd(), ...have].map((directory) => canonical(directory)),
  );
  const seen = new Set();
  const commands = [];
  const notes = [];

  for (const folder of folders) {
    const folderPath = folder?.path;
    if (typeof folderPath !== "string" || folderPath.length === 0) {
      console.error("error: a folder entry is missing path");
      process.exit(1);
    }
    const resolved = path.resolve(baseDir, expandHome(folderPath));
    const name = typeof folder.name === "string" ? folder.name : "";
    const label = name.length > 0 ? `${resolved} (${name})` : resolved;

    if (!isDirectory(resolved)) {
      notes.push(`missing: ${label}`);
      continue;
    }

    const directory = canonical(resolved);
    if (seen.has(directory)) continue;
    seen.add(directory);

    if (present.has(directory)) {
      notes.push(`already: ${directory}${name.length > 0 ? ` (${name})` : ""}`);
      continue;
    }

    commands.push(`/add-dir ${directory}`);
  }

  process.stdout.write([...commands, ...notes].join("\n") + (commands.length + notes.length > 0 ? "\n" : ""));
}

function parseArgs(args) {
  if (args.length === 0 || args.includes("-h") || args.includes("--help")) {
    console.error(usage);
    process.exit(args.length === 0 ? 1 : 0);
  }

  let workspaceFile;
  const have = [];
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--have") {
      const value = args[index + 1];
      if (!value || value.startsWith("-")) {
        console.error("error: --have requires a directory");
        process.exit(1);
      }
      have.push(value);
      index += 1;
      continue;
    }
    if (arg.startsWith("--have=")) {
      have.push(arg.slice("--have=".length));
      continue;
    }
    if (arg.startsWith("-")) {
      console.error(`error: unknown option ${arg}`);
      process.exit(1);
    }
    if (workspaceFile) {
      console.error("error: only one workspace file is accepted");
      process.exit(1);
    }
    workspaceFile = arg;
  }

  if (!workspaceFile) {
    console.error(usage);
    process.exit(1);
  }
  return { workspaceFile, have };
}

function readWorkspace(workspacePath) {
  let text;
  try {
    text = fs.readFileSync(workspacePath, "utf8");
  } catch (error) {
    console.error(
      `error: cannot read workspace file: ${error instanceof Error ? error.message : String(error)}`,
    );
    process.exit(1);
  }

  try {
    return parseJsonc(text);
  } catch (error) {
    console.error(
      `error: workspace file is not valid JSON: ${error instanceof Error ? error.message : String(error)}`,
    );
    process.exit(1);
  }
}

function expandHome(folderPath) {
  if (folderPath === "~") return os.homedir();
  if (folderPath.startsWith("~/")) return path.join(os.homedir(), folderPath.slice(2));
  return folderPath;
}

function isDirectory(directory) {
  try {
    return fs.statSync(directory).isDirectory();
  } catch {
    return false;
  }
}

function canonical(directory) {
  const resolved = path.resolve(directory);
  try {
    return fs.realpathSync(resolved);
  } catch {
    return resolved;
  }
}

function parseJsonc(text) {
  let output = "";
  let inString = false;
  let escaped = false;
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];
    if (inString) {
      output += char;
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === '"') inString = false;
      continue;
    }
    if (char === '"') {
      inString = true;
      output += char;
      continue;
    }
    if (char === "/" && next === "/") {
      index += 1;
      while (index + 1 < text.length && text[index + 1] !== "\n") index += 1;
      continue;
    }
    if (char === "/" && next === "*") {
      index += 2;
      while (index < text.length && !(text[index] === "*" && text[index + 1] === "/")) {
        index += 1;
      }
      index += 1;
      continue;
    }
    if (char === ",") {
      let lookAhead = index + 1;
      while (lookAhead < text.length && /\s/.test(text[lookAhead])) lookAhead += 1;
      if (text[lookAhead] === "}" || text[lookAhead] === "]") continue;
    }
    output += char;
  }
  return JSON.parse(output);
}
