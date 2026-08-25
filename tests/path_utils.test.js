#!/usr/bin/env node

const assert = require("assert");
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync("PathUtils.js", "utf8").replace(/^\.pragma library\s*/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

assert.equal(context.localFilePath("file:///tmp/plugin%20checkout/p2p-control"), "/tmp/plugin checkout/p2p-control");
assert.equal(context.localFilePath("/tmp/plain/p2p-control"), "/tmp/plain/p2p-control");
assert.equal(context.localFilePath("file:///tmp/bad%escape"), "/tmp/bad%escape");
assert.equal(context.localFilePath(""), "");

console.log("path utility tests passed");
