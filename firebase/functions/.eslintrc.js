module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
    tsconfigRootDir: __dirname,
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
    ".eslintrc.js",
  ],
  plugins: [
    // "@typescript-eslint",
    "import",
    "@typescript-eslint/eslint-plugin",
  ],
  rules: {
    quotes: ["error", "double"],
    "import/no-unresolved": 0,
    indent: ["error", 2],
    "max-lines-per-function": "off",
    "max-len": ["error", { code: 180 }],
    "object-curly-spacing": ["error", "always"],
    "quote-props": ["error", "as-needed"],
    "operator-linebreak": "off",
    "arrow-parens": ["error", "as-needed"],
    "valid-jsdoc": "off",
    indent: "off",
    "require-jsdoc": "off",
  },
};
