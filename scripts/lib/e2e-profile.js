"use strict";

const fs = require("fs");
const path = require("path");
const { ROOT } = require("./util");

function packageManager() {
  if (fs.existsSync(path.join(ROOT, "pnpm-lock.yaml"))) return "pnpm";
  if (fs.existsSync(path.join(ROOT, "yarn.lock"))) return "yarn";
  if (fs.existsSync(path.join(ROOT, "package-lock.json"))) return "npm";
  return null;
}

function commandForProfile(profile, manager) {
  if (profile === "playwright") {
    if (manager === "npm") {
      return [["npm", ["install", "--save-dev", "@playwright/test"]], ["npx", ["--no-install", "playwright", "install", "chromium"]]];
    }
    if (manager === "pnpm") {
      return [["pnpm", ["add", "--save-dev", "@playwright/test"]], ["pnpm", ["exec", "playwright", "install", "chromium"]]];
    }
    return [["yarn", ["add", "--dev", "@playwright/test"]], ["yarn", ["playwright", "install", "chromium"]]];
  }
  if (profile === "cypress") {
    if (manager === "npm") {
      return [["npm", ["install", "--save-dev", "cypress"]], ["npx", ["--no-install", "cypress", "install"]]];
    }
    if (manager === "pnpm") {
      return [["pnpm", ["add", "--save-dev", "cypress"]], ["pnpm", ["exec", "cypress", "install"]]];
    }
    return [["yarn", ["add", "--dev", "cypress"]], ["yarn", ["cypress", "install"]]];
  }
  return [];
}

function filesForProfile(profile) {
  if (profile === "node-api") {
    return {
      // Node의 --test는 test 디렉터리 인자를 이식성 있게 해석하지 않으므로,
      // 기본 탐색을 사용한다. 실제 E2E 테스트는 *.test.js 이름으로 작성한다.
      config: { command: "node", args: ["--test"] },
      files: [],
    };
  }
  if (profile === "playwright") {
    return {
      config: { command: "npx", args: ["--no-install", "playwright", "test"] },
      files: [["playwright.config.js", 'module.exports = { testDir: "tests/e2e" };\n']],
    };
  }
  return {
    config: { command: "npx", args: ["--no-install", "cypress", "run"] },
    files: [["cypress.config.js", 'module.exports = { e2e: { specPattern: "tests/e2e/**/*.cy.{js,ts}" } };\n']],
  };
}

module.exports = { packageManager, commandForProfile, filesForProfile };
