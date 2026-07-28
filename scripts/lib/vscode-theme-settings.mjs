#!/usr/bin/env node

import fs from "node:fs";

const [source, destination] = process.argv.slice(2);
if (!source || !destination) {
  console.error("Usage: vscode-theme-settings.mjs SOURCE DESTINATION");
  process.exit(2);
}

let text = fs.existsSync(source) ? fs.readFileSync(source, "utf8") : "{\n}\n";
const newline = text.includes("\r\n") ? "\r\n" : "\n";

function skipString(input, start) {
  let index = start + 1;
  while (index < input.length) {
    if (input[index] === "\\") {
      index += 2;
    } else if (input[index] === '"') {
      return index + 1;
    } else {
      index += 1;
    }
  }
  throw new Error("Unterminated string in VS Code settings");
}

function skipTrivia(input, start) {
  let index = start;
  while (index < input.length) {
    if (/\s/.test(input[index])) {
      index += 1;
    } else if (input.startsWith("//", index)) {
      const end = input.indexOf("\n", index + 2);
      index = end === -1 ? input.length : end + 1;
    } else if (input.startsWith("/*", index)) {
      const end = input.indexOf("*/", index + 2);
      if (end === -1) throw new Error("Unterminated comment in VS Code settings");
      index = end + 2;
    } else {
      break;
    }
  }
  return index;
}

function findProperty(input, wanted) {
  let depth = 0;
  let index = 0;
  while (index < input.length) {
    if (input.startsWith("//", index) || input.startsWith("/*", index)) {
      index = skipTrivia(input, index);
      continue;
    }
    if (input[index] === '"') {
      const stringEnd = skipString(input, index);
      if (depth === 1) {
        const key = JSON.parse(input.slice(index, stringEnd));
        const colon = skipTrivia(input, stringEnd);
        if (key === wanted && input[colon] === ":") {
          const valueStart = skipTrivia(input, colon + 1);
          let valueEnd = valueStart;
          let nested = 0;
          while (valueEnd < input.length) {
            if (nested === 0 && (input.startsWith("//", valueEnd) || input.startsWith("/*", valueEnd))) {
              break;
            }
            if (input.startsWith("//", valueEnd) || input.startsWith("/*", valueEnd)) {
              valueEnd = skipTrivia(input, valueEnd);
              continue;
            }
            if (input[valueEnd] === '"') {
              valueEnd = skipString(input, valueEnd);
              continue;
            }
            if (input[valueEnd] === "{" || input[valueEnd] === "[") nested += 1;
            if (input[valueEnd] === "}" || input[valueEnd] === "]") {
              if (nested === 0) break;
              nested -= 1;
            }
            if (nested === 0 && input[valueEnd] === ",") break;
            valueEnd += 1;
          }
          while (valueEnd > valueStart && /\s/.test(input[valueEnd - 1])) valueEnd -= 1;
          return { valueStart, valueEnd };
        }
      }
      index = stringEnd;
      continue;
    }
    if (input[index] === "{" || input[index] === "[") depth += 1;
    if (input[index] === "}" || input[index] === "]") depth -= 1;
    index += 1;
  }
  return null;
}

function closingBrace(input) {
  let depth = 0;
  let index = 0;
  while (index < input.length) {
    if (input.startsWith("//", index) || input.startsWith("/*", index)) {
      index = skipTrivia(input, index);
      continue;
    }
    if (input[index] === '"') {
      index = skipString(input, index);
      continue;
    }
    if (input[index] === "{") depth += 1;
    if (input[index] === "}") {
      depth -= 1;
      if (depth === 0) return index;
    }
    index += 1;
  }
  throw new Error("VS Code settings must contain a top-level JSON object");
}

function setProperty(input, key, value) {
  const property = findProperty(input, key);
  if (property) {
    return input.slice(0, property.valueStart) + value + input.slice(property.valueEnd);
  }

  const end = closingBrace(input);
  let previous = end - 1;
  while (previous >= 0 && /\s/.test(input[previous])) previous -= 1;
  const comma = input[previous] === "{" || input[previous] === "," ? "" : ",";
  const prefix = input.slice(0, end).replace(/\s*$/, "");
  return `${prefix}${comma}${newline}  ${JSON.stringify(key)}: ${value}${newline}${input.slice(end)}`;
}

const settings = new Map([
  ["window.autoDetectColorScheme", "true"],
  ["workbench.preferredLightColorTheme", JSON.stringify("Tokyo Night Light")],
  ["workbench.preferredDarkColorTheme", JSON.stringify("Tokyo Night")],
]);

for (const [key, value] of settings) text = setProperty(text, key, value);
fs.writeFileSync(destination, text);
