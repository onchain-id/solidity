import js from "@eslint/js";
import prettierConfig from "eslint-config-prettier";
import importPlugin from "eslint-plugin-import";
import nodePlugin from "eslint-plugin-node";
import prettier from "eslint-plugin-prettier";
import promisePlugin from "eslint-plugin-promise";

export default [
  {
    ignores: [
      "node_modules/**",
      "dependencies/**",
      "artifacts/**",
      "cache/**",
      "coverage/**",
      "**/coverage/**",
      "**/node_modules/**",
      "**/coverage/lcov-report/**",
      "**/coverage/prettify.js",
      "**/coverage/sorter.js",
    ],
  },
  js.configs.recommended,
  prettierConfig,
  {
    files: ["**/*.js", "**/*.ts"],
    plugins: {
      prettier,
      import: importPlugin,
      node: nodePlugin,
      promise: promisePlugin,
    },
    rules: {
      "prettier/prettier": "error",
      "no-unused-vars": "warn",
      "no-console": "off",
      "prefer-const": "error",
      "no-var": "error",
    },
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: "module",
      globals: {
        console: "readonly",
        process: "readonly",
        Buffer: "readonly",
        __dirname: "readonly",
        __filename: "readonly",
        global: "readonly",
        module: "readonly",
        require: "readonly",
        exports: "readonly",
      },
    },
  },
];
